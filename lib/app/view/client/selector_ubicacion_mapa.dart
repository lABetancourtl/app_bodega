import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/service/location_service.dart';

class SelectorUbicacionMapa extends StatefulWidget {
  final double? latitudInicial;
  final double? longitudInicial;

  const SelectorUbicacionMapa({
    super.key,
    this.latitudInicial,
    this.longitudInicial,
  });

  @override
  State<SelectorUbicacionMapa> createState() => _SelectorUbicacionMapaState();
}

class _SelectorUbicacionMapaState extends State<SelectorUbicacionMapa> {
  final MapController _mapController = MapController();
  LatLng? _ubicacionSeleccionada;
  bool _cargandoUbicacion = false;

  @override
  void initState() {
    super.initState();
    if (widget.latitudInicial != null && widget.longitudInicial != null) {
      _ubicacionSeleccionada = LatLng(widget.latitudInicial!, widget.longitudInicial!);
    } else {
      _obtenerUbicacionActual();
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() => _cargandoUbicacion = true);

    final locationService = LocationService();
    final position = await locationService.obtenerUbicacionActual();

    if (position != null && mounted) {
      setState(() {
        _ubicacionSeleccionada = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_ubicacionSeleccionada!, 15.0);
    }

    setState(() => _cargandoUbicacion = false);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _ubicacionSeleccionada = point;
    });
  }

  void _confirmarUbicacion() {
    if (_ubicacionSeleccionada != null) {
      Navigator.pop(context, {
        'latitud': _ubicacionSeleccionada!.latitude,
        'longitud': _ubicacionSeleccionada!.longitude,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _ubicacionSeleccionada != null ? _confirmarUbicacion : null,
            tooltip: 'Confirmar ubicación',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionSeleccionada ?? const LatLng(4.5339, -75.6811),
              initialZoom: 15.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_ubicacionSeleccionada != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _ubicacionSeleccionada!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Instrucciones
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.touch_app, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Toca el mapa para seleccionar una ubicación',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (_ubicacionSeleccionada != null) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lat: ${_ubicacionSeleccionada!.latitude.toStringAsFixed(6)}\n'
                                  'Lon: ${_ubicacionSeleccionada!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 11, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Botones de control
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mi ubicación
                FloatingActionButton(
                  heroTag: 'miUbicacion',
                  onPressed: _cargandoUbicacion ? null : _obtenerUbicacionActual,
                  tooltip: 'Mi ubicación actual',
                  child: _cargandoUbicacion
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                // Zoom in
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                // Zoom out
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Botón confirmar (abajo centro)
          if (_ubicacionSeleccionada != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 80,
              child: ElevatedButton.icon(
                onPressed: _confirmarUbicacion,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmar Ubicación'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}