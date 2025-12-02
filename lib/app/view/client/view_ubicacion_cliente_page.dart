import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';

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
    }

    setState(() => _cargandoUbicacion = false);
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

    // Marcador del cliente - AUMENTADO EL HEIGHT
    marcadores.add(
      Marker(
        point: ubicacionCliente,
        width: 100,
        height: 120, // Aumentado de 100 a 120
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
          // Toggle para mostrar/ocultar mi ubicación
          if (_miUbicacion != null)
            IconButton(
              icon: Icon(
                _mostrarMiUbicacion ? Icons.visibility : Icons.visibility_off,
                color: _mostrarMiUbicacion ? Colors.green : Colors.grey,
              ),
              tooltip: _mostrarMiUbicacion ? 'Ocultar mi ubicación' : 'Mostrar mi ubicación',
              onPressed: () {
                setState(() {
                  _mostrarMiUbicacion = !_mostrarMiUbicacion;
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

          // Panel de controles flotante
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
                    backgroundColor: Colors.purple,
                    tooltip: 'Ver ambos en mapa',
                    onPressed: _verAmbosEnMapa,
                    child: const Icon(Icons.fit_screen, size: 20),
                  ),

                if (_miUbicacion != null && _mostrarMiUbicacion)
                  const SizedBox(height: 8),

                // Mi ubicación
                FloatingActionButton(
                  heroTag: 'miUbicacion',
                  mini: true,
                  backgroundColor: _cargandoUbicacion ? Colors.grey : Colors.green,
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
                      : const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 8),

                // Centrar en cliente
                FloatingActionButton(
                  heroTag: 'centrarCliente',
                  mini: true,
                  backgroundColor: Colors.blue,
                  tooltip: 'Centrar en cliente',
                  onPressed: _centrarEnCliente,
                  child: const Icon(Icons.store, size: 20),
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
                  child: const Icon(Icons.add, color: Colors.black87, size: 20),
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
                  child: const Icon(Icons.remove, color: Colors.black87, size: 20),
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
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Mostrar distancia si está disponible
              if (distancia != null && _mostrarMiUbicacion) ...[
                Row(
                  children: [
                    Icon(Icons.social_distance, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Distancia: ${distancia < 1000 ? "${distancia.toStringAsFixed(0)} m" : "${(distancia / 1000).toStringAsFixed(2)} km"}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
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

              // Indicador de carga de ubicación
              if (_cargandoUbicacion) ...[
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
                      'Obteniendo tu ubicación...',
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