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
  LatLng? _miUbicacionActual;
  bool _cargandoUbicacion = false;
  bool _mostrarMiUbicacion = true;

  @override
  void initState() {
    super.initState();
    _inicializarUbicacion();
  }

  Future<void> _inicializarUbicacion() async {
    // Si hay ubicación inicial proporcionada, usarla
    if (widget.latitudInicial != null && widget.longitudInicial != null) {
      setState(() {
        _ubicacionSeleccionada = LatLng(widget.latitudInicial!, widget.longitudInicial!);
      });
    } else {
      // Si no, obtener la ubicación actual con alta precisión
      await _obtenerUbicacionActual();

      // Establecer la ubicación seleccionada como la ubicación actual
      if (_miUbicacionActual != null) {
        setState(() {
          _ubicacionSeleccionada = _miUbicacionActual;
        });
      }
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() => _cargandoUbicacion = true);

    final locationService = LocationService();
    final position = await locationService.obtenerUbicacionActual();

    if (position != null && mounted) {
      final ubicacion = LatLng(position.latitude, position.longitude);

      setState(() {
        _miUbicacionActual = ubicacion;
      });

      // Centrar el mapa en la ubicación actual
      _mapController.move(ubicacion, 17.0);
    } else {
      // Si falla, usar una ubicación por defecto (Armenia, Quindío)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación. Selecciona manualmente.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() => _cargandoUbicacion = false);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _ubicacionSeleccionada = point;
    });
  }

  void _centrarEnMiUbicacion() {
    if (_miUbicacionActual != null) {
      _mapController.move(_miUbicacionActual!, 17.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no disponible')),
      );
    }
  }

  void _usarMiUbicacion() {
    if (_miUbicacionActual != null) {
      setState(() {
        _ubicacionSeleccionada = _miUbicacionActual;
      });
      _mapController.move(_miUbicacionActual!, 17.0);
    }
  }

  void _confirmarUbicacion() {
    if (_ubicacionSeleccionada != null) {
      Navigator.pop(context, {
        'latitud': _ubicacionSeleccionada!.latitude,
        'longitud': _ubicacionSeleccionada!.longitude,
      });
    }
  }

  List<Marker> _construirMarcadores() {
    final marcadores = <Marker>[];

    // Marcador de la ubicación seleccionada
    if (_ubicacionSeleccionada != null) {
      marcadores.add(
        Marker(
          point: _ubicacionSeleccionada!,
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: const Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 50,
          ),
        ),
      );
    }

    // Marcador de mi ubicación actual (si está disponible y es diferente)
    if (_miUbicacionActual != null && _mostrarMiUbicacion) {
      final esLaMismaUbicacion = _ubicacionSeleccionada != null &&
          (_ubicacionSeleccionada!.latitude - _miUbicacionActual!.latitude).abs() < 0.0001 &&
          (_ubicacionSeleccionada!.longitude - _miUbicacionActual!.longitude).abs() < 0.0001;

      if (!esLaMismaUbicacion) {
        marcadores.add(
          Marker(
            point: _miUbicacionActual!,
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 20,
              ),
            ),
          ),
        );
      }
    }

    return marcadores;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Ubicación'),
        actions: [
          if (_miUbicacionActual != null)
            IconButton(
              icon: Icon(
                _mostrarMiUbicacion ? Icons.visibility : Icons.visibility_off,
                color: _mostrarMiUbicacion ? Colors.black45 : Colors.grey,
              ),
              tooltip: _mostrarMiUbicacion ? 'Ocultar mi ubicación' : 'Mostrar mi ubicación',
              onPressed: () {
                setState(() {
                  _mostrarMiUbicacion = !_mostrarMiUbicacion;
                });
              },
            ),
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
              initialCenter: _ubicacionSeleccionada ??
                  _miUbicacionActual ??
                  const LatLng(4.5339, -75.6811), // Armenia, Quindío por defecto
              initialZoom: 17.0,
              minZoom: 3,
              maxZoom: 19,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
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

          // Instrucciones
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.touch_app, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Toca el mapa para seleccionar una ubicación',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_cargandoUbicacion) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Obteniendo ubicación con precisión...',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
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
            bottom: _ubicacionSeleccionada != null ? 80 : 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Usar mi ubicación actual
                if (_miUbicacionActual != null)
                  FloatingActionButton(
                    heroTag: 'usarMiUbicacion',
                    backgroundColor: Colors.green,
                    tooltip: 'Usar mi ubicación actual',
                    onPressed: _usarMiUbicacion,
                    child: const Icon(Icons.gps_fixed, color: Colors.white),
                  ),

                if (_miUbicacionActual != null)
                  const SizedBox(height: 8),

                // Mi ubicación (centrar)
                FloatingActionButton(
                  heroTag: 'miUbicacion',
                  backgroundColor: Colors.white,
                  onPressed: _cargandoUbicacion ? null : _centrarEnMiUbicacion,
                  tooltip: 'Centrar en mi ubicación',
                  child: _cargandoUbicacion
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                      : const Icon(Icons.my_location, color: Colors.black),
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
                  child: const Icon(Icons.add, color: Colors.black),
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
                  elevation: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}