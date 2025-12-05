import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../widgets/cliente_pulse_market.dart';
import '../../widgets/pulse_marker.dart';

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

  Future<void> _cargarMiUbicacion() async {
    setState(() => _cargandoUbicacion = true);

    final locationService = LocationService();
    final position = await locationService.obtenerUbicacionActual();

    if (position != null && mounted) {
      setState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });

      // Cargar ruta automáticamente cuando se obtiene la ubicación
      if (_mostrarRuta) {
        _cargarRutaReal();
      }
    }

    setState(() => _cargandoUbicacion = false);
  }

  // Nueva función para obtener la ruta real usando OSRM
  Future<void> _cargarRutaReal() async {
    if (_miUbicacion == null || widget.cliente.latitud == null) return;

    setState(() => _cargandoRuta = true);

    try {
      final start = _miUbicacion!;
      final end = LatLng(widget.cliente.latitud!, widget.cliente.longitud!);

      // Llamar al servicio OSRM (Open Source Routing Machine)
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

          // Convertir coordenadas a LatLng
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
      // En caso de error, mostrar línea recta como fallback
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

    // Marcador del cliente - AHORA CON PRECISIÓN PERFECTA
    marcadores.add(
      Marker(
        point: ubicacionCliente,
        width: 80,
        height: 100, // Ajustado para incluir el nombre debajo
        alignment: Alignment.center,
        child: ClientePulseMarker(
          nombre: widget.cliente.nombreNegocio,
          ruta: widget.cliente.ruta,
        ),
      ),
    );

    // Marcador de mi ubicación (si está disponible y activado)
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

  // Nueva función para construir la línea de ruta REAL
  List<Polyline> _construirRuta() {
    if (!_mostrarRuta || !_mostrarMiUbicacion) {
      return [];
    }

    // Si todavía no hay ruta cargada, no mostrar nada
    if (_puntosRuta.isEmpty) {
      return [];
    }

    return [
      Polyline(
        points: _puntosRuta,
        strokeWidth: 5.0,
        color: Colors.blue.withOpacity(0.8),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no disponible')),
      );
    }
  }

  void _verAmbosEnMapa() {
    if (_miUbicacion != null) {
      // Calcular bounds para mostrar ambos puntos
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

  @override
  Widget build(BuildContext context) {
    final tieneUbicacion = widget.cliente.latitud != null && widget.cliente.longitud != null;

    if (!tieneUbicacion) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ubicación del Negocio'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay ubicación registrada',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'para ${widget.cliente.nombreNegocio}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ubicacion = LatLng(widget.cliente.latitud!, widget.cliente.longitud!);
    final distancia = _calcularDistancia();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación del Negocio'),
        centerTitle: true,
        actions: [
          if (_miUbicacion != null)
            IconButton(
              icon: Icon(
                Icons.my_location,
                color: _seguirUbicacion ? Colors.blue : Colors.black45,
              ),
              tooltip: _seguirUbicacion ? 'Desactivar seguimiento' : 'Seguir mi ubicación',
              onPressed: () {
                setState(() {
                  _seguirUbicacion = !_seguirUbicacion;
                  // if (_seguirUbicacion && _miUbicacion != null) {
                  //   _mapController.move(_miUbicacion!, _mapController.camera.zoom);
                  // }
                });
              },
            ),

          // Toggle para mostrar/ocultar ruta
          if (_miUbicacion != null && _mostrarMiUbicacion)
            IconButton(
              icon: _cargandoRuta
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(
                _mostrarRuta ? Icons.route : Icons.route_outlined,
                color: _mostrarRuta ? Colors.black45 : Colors.grey,
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
          // Toggle para mostrar/ocultar mi ubicación
          if (_miUbicacion != null)
            IconButton(
              icon: Icon(
                _mostrarMiUbicacion ? Icons.visibility : Icons.visibility_off,
                color: _mostrarMiUbicacion ? Colors.black45 : Colors.grey,
              ),
              tooltip: _mostrarMiUbicacion ? 'Ocultar mi ubicación' : 'Mostrar mi ubicación',
              onPressed: () {
                setState(() {
                  _mostrarMiUbicacion = !_mostrarMiUbicacion;
                  if (!_mostrarMiUbicacion) {
                    _mostrarRuta = false; // Ocultar ruta si se oculta ubicación
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
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                // urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', //Estilo oscuro
                // urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', //Estilo claro/minimalista
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', //Estilo Voyager
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bodega.app_bodega',
                maxZoom: 19,
              ),
              PolylineLayer(
                polylines: _construirRuta(),
              ),
              MarkerLayer(
                markers: _construirMarcadores(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            bottom: 200,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centrar en ambos (si hay ubicación actual)
                if (_miUbicacion != null && _mostrarMiUbicacion)
                  FloatingActionButton(
                    heroTag: 'verAmbos',
                    mini: true,
                    backgroundColor: Colors.white,
                    tooltip: 'Ver ambos en mapa',
                    onPressed: _verAmbosEnMapa,
                    child: const Icon(Icons.fit_screen, size: 20, color: Colors.black,),
                  ),

                if (_miUbicacion != null && _mostrarMiUbicacion)
                  const SizedBox(height: 8),

                // Mi ubicación
                FloatingActionButton(
                  heroTag: 'miUbicacion',
                  mini: true,
                  backgroundColor: _cargandoUbicacion ? Colors.grey : Colors.white,
                  tooltip: 'Mi ubicación',
                  onPressed: _cargandoUbicacion ? null : _centrarEnMiUbicacion,
                  child: _cargandoUbicacion
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.my_location, size: 20, color: Colors.black),
                ),
                const SizedBox(height: 8),

                // Centrar en cliente
                FloatingActionButton(
                  heroTag: 'centrarCliente',
                  mini: true,
                  backgroundColor: Colors.white,
                  tooltip: 'Centrar en cliente',
                  onPressed: _centrarEnCliente,
                  child: const Icon(Icons.store, size: 20, color: Colors.black),
                ),
                const SizedBox(height: 8),

                // Zoom in
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add, color: Colors.black, ),
                ),
                const SizedBox(height: 8),

                // Zoom out
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.cliente.nombreNegocio,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.cliente.direccion,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Mostrar distancia si está disponible
              if (distancia != null && _mostrarMiUbicacion) ...[
                Row(
                  // children: [
                  //   Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                  //   const SizedBox(width: 8),
                  //   Expanded(
                  //     child: Text(
                  //       'Distancia en línea recta: ${distancia < 1000 ? "${distancia.toStringAsFixed(0)} m" : "${(distancia / 1000).toStringAsFixed(2)} km"}',
                  //       style: TextStyle(
                  //         fontSize: 13,
                  //         color: Colors.grey[700],
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //   ),
                  // ],
                ),
                const SizedBox(height: 4),
              ],

              // Muestra distancia de la ruta real
              if (_distanciaRuta != null && _mostrarRuta && _mostrarMiUbicacion) ...[
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Distancia por carretera: ${_distanciaRuta! < 1000 ? "${_distanciaRuta!.toStringAsFixed(0)} m" : "${(_distanciaRuta! / 1000).toStringAsFixed(2)} km"}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Mostrar tiempo estimado
              if (_duracionRuta != null && _mostrarRuta && _mostrarMiUbicacion) ...[
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tiempo estimado: ${(_duracionRuta! / 60).toStringAsFixed(0)} min',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Text(
                'Coordenadas: ${widget.cliente.latitud?.toStringAsFixed(6)}, ${widget.cliente.longitud?.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),

              // Indicador de carga de ubicación o ruta
              if (_cargandoUbicacion || _cargandoRuta) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _cargandoUbicacion
                          ? 'Obteniendo tu ubicación...'
                          : 'Calculando ruta...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}