import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/cliente_pulse_market.dart';
import '../../widgets/pulse_marker.dart';
import 'package:app_bodega/app/theme/app_colors.dart';


class ViewUbicacionClientePage extends StatefulWidget {
  final ClienteModel cliente;

  const ViewUbicacionClientePage({
    super.key,
    required this.cliente,
  });

  @override
  State<ViewUbicacionClientePage> createState() => _ViewUbicacionClientePageState();
}

class _ViewUbicacionClientePageState extends State<ViewUbicacionClientePage> {
  final MapController _mapController = MapController();
  LatLng? _miUbicacion;
  bool _cargandoUbicacion = false;
  bool _mostrarMiUbicacion = true;
  bool _mostrarRuta = true;
  List<LatLng> _puntosRuta = [];
  bool _cargandoRuta = false;
  double? _distanciaRuta;
  double? _duracionRuta;

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _seguirUbicacion = false;

  @override
  void initState() {
    super.initState();
    _cargarMiUbicacion();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _mostrarSnackBar(String mensaje, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : (isError ? Icons.error : Icons.info),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.accent : (isError ? AppColors.error : AppColors.primary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Future<void> _cargarMiUbicacion() async {
    setState(() => _cargandoUbicacion = true);

    final locationService = LocationService();
    final position = await locationService.obtenerUbicacionActual();

    if (position != null && mounted) {
      setState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });

      if (_mostrarRuta) {
        _cargarRutaReal();
      }
    }

    setState(() => _cargandoUbicacion = false);
  }

  Future<void> _cargarRutaReal() async {
    if (_miUbicacion == null || widget.cliente.latitud == null) return;

    setState(() => _cargandoRuta = true);

    try {
      final start = _miUbicacion!;
      final end = LatLng(widget.cliente.latitud!, widget.cliente.longitud!);

      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;

          final puntos = geometry.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          if (mounted) {
            setState(() {
              _puntosRuta = puntos;
              _distanciaRuta = route['distance'] as double?;
              _duracionRuta = route['duration'] as double?;
            });
          }
        }
      }
    } catch (e) {
      print('Error cargando ruta: $e');
      if (mounted) {
        setState(() {
          _puntosRuta = [
            _miUbicacion!,
            LatLng(widget.cliente.latitud!, widget.cliente.longitud!)
          ];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoRuta = false);
      }
    }
  }

  Future<void> _navegarACliente() async {
    if (widget.cliente.latitud == null || widget.cliente.longitud == null) {
      _mostrarSnackBar('Este cliente no tiene ubicación', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.navigation, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Navegar a',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          widget.cliente.nombreNegocio ?? widget.cliente.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.map, color: AppColors.primary, size: 24),
              ),
              title: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Abrir en Google Maps', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${widget.cliente.latitud},${widget.cliente.longitud}',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    _mostrarSnackBar('No se pudo abrir Google Maps', isError: true);
                  }
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.navigation, color: AppColors.primary, size: 24),
              ),
              title: const Text('Waze', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Abrir en Waze', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                final url = Uri.parse(
                  'https://waze.com/ul?ll=${widget.cliente.latitud},${widget.cliente.longitud}&navigate=yes',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    _mostrarSnackBar('No se pudo abrir Waze', isError: true);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  double? _calcularDistancia() {
    if (_miUbicacion == null || widget.cliente.latitud == null) return null;

    final locationService = LocationService();
    return locationService.calcularDistancia(
      lat1: _miUbicacion!.latitude,
      lon1: _miUbicacion!.longitude,
      lat2: widget.cliente.latitud!,
      lon2: widget.cliente.longitud!,
    );
  }

  List<Marker> _construirMarcadores() {
    final marcadores = <Marker>[];
    final ubicacionCliente = LatLng(widget.cliente.latitud!, widget.cliente.longitud!);

    marcadores.add(
      Marker(
        point: ubicacionCliente,
        width: 80,
        height: 100,
        alignment: Alignment.center,
        child: ClientePulseMarker(
          nombre: widget.cliente.nombreNegocio,
          ruta: widget.cliente.ruta,
        ),
      ),
    );

    if (_miUbicacion != null && _mostrarMiUbicacion) {
      marcadores.add(
        Marker(
          point: _miUbicacion!,
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: const PulseMarker(),
        ),
      );
    }

    return marcadores;
  }

  List<Polyline> _construirRuta() {
    if (!_mostrarRuta || !_mostrarMiUbicacion || _puntosRuta.isEmpty) {
      return [];
    }

    return [
      Polyline(
        points: _puntosRuta,
        strokeWidth: 5.0,
        color: AppColors.primary.withOpacity(0.8),
        borderStrokeWidth: 2.0,
        borderColor: Colors.white,
      ),
    ];
  }

  void _centrarEnCliente() {
    _mapController.move(
      LatLng(widget.cliente.latitud!, widget.cliente.longitud!),
      16.0,
    );
  }

  void _centrarEnMiUbicacion() {
    if (_miUbicacion != null) {
      _mapController.move(_miUbicacion!, 16.0);
    } else {
      _mostrarSnackBar('Ubicación no disponible', isError: true);
    }
  }

  void _verAmbosEnMapa() {
    if (_miUbicacion != null) {
      final bounds = LatLngBounds(
        LatLng(widget.cliente.latitud!, widget.cliente.longitud!),
        _miUbicacion!,
      );

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tieneUbicacion = widget.cliente.latitud != null && widget.cliente.longitud != null;

    if (!tieneUbicacion) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: const Text('Ubicación del Negocio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary)),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_off, size: 64, color: AppColors.primary.withOpacity(0.3)),
              ),
              const SizedBox(height: 24),
              const Text('No hay ubicación registrada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'para ${widget.cliente.nombreNegocio ?? widget.cliente.nombre}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final ubicacion = LatLng(widget.cliente.latitud!, widget.cliente.longitud!);
    final distancia = _calcularDistancia();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Ubicación del Negocio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        centerTitle: true,
        actions: [
          if (_miUbicacion != null)
            IconButton(
              icon: Icon(
                Icons.my_location,
                color: _seguirUbicacion ? AppColors.accent : AppColors.textSecondary,
              ),
              tooltip: _seguirUbicacion ? 'Desactivar seguimiento' : 'Seguir mi ubicación',
              onPressed: () {
                setState(() {
                  _seguirUbicacion = !_seguirUbicacion;
                });
              },
            ),
          if (_miUbicacion != null && _mostrarMiUbicacion)
            IconButton(
              icon: _cargandoRuta
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : Icon(
                _mostrarRuta ? Icons.route : Icons.route_outlined,
                color: _mostrarRuta ? AppColors.primary : AppColors.textSecondary,
              ),
              tooltip: _mostrarRuta ? 'Ocultar ruta' : 'Mostrar ruta',
              onPressed: _cargandoRuta
                  ? null
                  : () {
                setState(() {
                  _mostrarRuta = !_mostrarRuta;
                  if (_mostrarRuta && _puntosRuta.isEmpty) {
                    _cargarRutaReal();
                  }
                });
              },
            ),
          if (_miUbicacion != null)
            IconButton(
              icon: Icon(
                _mostrarMiUbicacion ? Icons.visibility : Icons.visibility_off,
                color: _mostrarMiUbicacion ? AppColors.primary : AppColors.textSecondary,
              ),
              tooltip: _mostrarMiUbicacion ? 'Ocultar mi ubicación' : 'Mostrar mi ubicación',
              onPressed: () {
                setState(() {
                  _mostrarMiUbicacion = !_mostrarMiUbicacion;
                  if (!_mostrarMiUbicacion) {
                    _mostrarRuta = false;
                  }
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: ubicacion,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bodega.app_bodega',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _construirRuta()),
              MarkerLayer(markers: _construirMarcadores()),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
                ],
              ),
            ],
          ),

          // Controles del mapa
          Positioned(
            bottom: 200,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_miUbicacion != null && _mostrarMiUbicacion)
                  _buildMapButton(
                    heroTag: 'verAmbos',
                    icon: Icons.fit_screen,
                    tooltip: 'Ver ambos en mapa',
                    onPressed: _verAmbosEnMapa,
                  ),
                if (_miUbicacion != null && _mostrarMiUbicacion) const SizedBox(height: 8),
                _buildMapButton(
                  heroTag: 'miUbicacion',
                  icon: Icons.my_location,
                  tooltip: 'Mi ubicación',
                  isLoading: _cargandoUbicacion,
                  onPressed: _cargandoUbicacion ? null : _centrarEnMiUbicacion,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  heroTag: 'centrarCliente',
                  icon: Icons.store,
                  tooltip: 'Centrar en cliente',
                  onPressed: _centrarEnCliente,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  heroTag: 'zoomIn',
                  icon: Icons.add,
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  heroTag: 'zoomOut',
                  icon: Icons.remove,
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cliente.nombreNegocio ?? 'Sin negocio',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          widget.cliente.nombre,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.location_on, 'Dirección', widget.cliente.direccion ?? 'Sin dirección'),

              if (_distanciaRuta != null && _mostrarRuta && _mostrarMiUbicacion) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.directions_car,
                  'Distancia por carretera',
                  _distanciaRuta! < 1000 ? '${_distanciaRuta!.toStringAsFixed(0)} m' : '${(_distanciaRuta! / 1000).toStringAsFixed(2)} km',
                ),
              ],

              if (_duracionRuta != null && _mostrarRuta && _mostrarMiUbicacion) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Tiempo estimado', '${(_duracionRuta! / 60).toStringAsFixed(0)} min'),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navegarACliente,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Iniciar Navegación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required String heroTag,
    required IconData icon,
    String? tooltip,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: AppColors.surface,
      tooltip: tooltip,
      elevation: 2,
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : Icon(icon, size: 20, color: AppColors.primary),
    );
  }
}