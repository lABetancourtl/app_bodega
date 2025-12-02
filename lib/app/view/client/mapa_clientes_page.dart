import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';

import '../../widgets/clientes_pulse_market.dart';
import '../../widgets/pulse_marker.dart';

class MapaClientesPage extends StatefulWidget {
  final List<ClienteModel> clientes;

  const MapaClientesPage({
    super.key,
    required this.clientes,
  });

  @override
  State<MapaClientesPage> createState() => _MapaClientesPageState();
}

class _MapaClientesPageState extends State<MapaClientesPage> {
  final MapController _mapController = MapController();
  LatLng? _miUbicacion;
  bool _cargandoUbicacion = false;
  Ruta? _filtroRuta;
  ClienteModel? _clienteSeleccionado;

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

      // Centrar mapa en mi ubicación
      _mapController.move(_miUbicacion!, 13.0);
    }

    setState(() => _cargandoUbicacion = false);
  }

  List<ClienteModel> get clientesFiltrados {
    final conUbicacion = widget.clientes
        .where((c) => c.latitud != null && c.longitud != null);

    if (_filtroRuta == null) return conUbicacion.toList();
    return conUbicacion.where((c) => c.ruta == _filtroRuta).toList();
  }

  List<Marker> _construirMarcadores() {
    final marcadores = <Marker>[];

    // Marcador de mi ubicación (más grande y destacado)
    if (_miUbicacion != null) {
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

    // Marcadores de clientes - AUMENTADO EL HEIGHT
    for (final cliente in clientesFiltrados) {
      if (cliente.latitud != null && cliente.longitud != null) {
        final esSeleccionado = _clienteSeleccionado?.id == cliente.id;

        marcadores.add(
          Marker(
            point: LatLng(cliente.latitud!, cliente.longitud!),
            width: 100,
            height: 120, // Aumentado de 100 a 120
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _mostrarInfoCliente(cliente),
              child: ClientesPulseMarker(
                nombre: cliente.nombreNegocio,
                color: _getColorRuta(cliente.ruta),
                esSeleccionado: esSeleccionado,
              ),
            ),
          ),
        );
      }
    }
    return marcadores;
  }

  Color _getColorRuta(Ruta? ruta) {
    if (ruta == null) return Colors.grey;

    switch (ruta) {
      case Ruta.ruta1:
        return Colors.orange;
      case Ruta.ruta2:
        return Colors.red;
      case Ruta.ruta3:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  void _mostrarInfoCliente(ClienteModel cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
    });

    _mapController.move(
      LatLng(cliente.latitud!, cliente.longitud!),
      16.0,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle del modal
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título con icono de ruta
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getColorRuta(cliente.ruta),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombreNegocio,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (cliente.ruta != null)
                          Text(
                            cliente.ruta.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getColorRuta(cliente.ruta),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Información del cliente
              _buildInfoRow(Icons.person, 'Cliente', cliente.nombre),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on, 'Dirección', cliente.direccion),

              if (cliente.telefono != null && cliente.telefono!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, 'Teléfono', cliente.telefono!),
              ],

              if (_miUbicacion != null && cliente.latitud != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.social_distance,
                  'Distancia',
                  '${_calcularDistancia(cliente).toStringAsFixed(0)} metros',
                ),
              ],

              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.my_location,
                'Coordenadas',
                '${cliente.latitud?.toStringAsFixed(6)}, ${cliente.longitud?.toStringAsFixed(6)}',
              ),

              const SizedBox(height: 20),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _clienteSeleccionado = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Aquí puedes navegar a los detalles del cliente
                        // Navigator.push(context, MaterialPageRoute(...))
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('Ver Detalles'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: _getColorRuta(cliente.ruta),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      setState(() {
        _clienteSeleccionado = null;
      });
    });
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calcularDistancia(ClienteModel cliente) {
    if (_miUbicacion == null || cliente.latitud == null) return 0;

    final locationService = LocationService();
    return locationService.calcularDistancia(
      lat1: _miUbicacion!.latitude,
      lon1: _miUbicacion!.longitude,
      lat2: cliente.latitud!,
      lon2: cliente.longitud!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesConUbicacion = widget.clientes
        .where((c) => c.latitud != null && c.longitud != null)
        .length;

    final clientesSinUbicacion = widget.clientes.length - clientesConUbicacion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Clientes'),
        centerTitle: true,
        actions: [
          // Filtro por ruta
          PopupMenuButton<Ruta?>(
            icon: Icon(
              Icons.filter_list,
              color: _filtroRuta != null ? _getColorRuta(_filtroRuta!) : null,
            ),
            tooltip: 'Filtrar por ruta',
            onSelected: (ruta) {
              setState(() => _filtroRuta = ruta);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 12),
                    Text('Todas las rutas'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...Ruta.values.map((ruta) => PopupMenuItem(
                value: ruta,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getColorRuta(ruta),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(ruta.toString().split('.').last.toUpperCase()),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa principal
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(4.5339, -75.6811),
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 19.0,
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

          // Panel de información superior
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Total: ${widget.clientes.length} clientes',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChip(
                          Icons.location_on,
                          '$clientesConUbicacion con ubicación',
                          Colors.green,
                        ),
                        const SizedBox(width: 8),
                        if (clientesSinUbicacion > 0)
                          _buildChip(
                            Icons.location_off,
                            '$clientesSinUbicacion sin ubicación',
                            Colors.orange,
                          ),
                      ],
                    ),
                    if (_filtroRuta != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorRuta(_filtroRuta!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getColorRuta(_filtroRuta!),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 14,
                              color: _getColorRuta(_filtroRuta!),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Mostrando: ${_filtroRuta.toString().split('.').last.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getColorRuta(_filtroRuta!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Controles de mapa (derecha)
          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mi ubicación
                FloatingActionButton(
                  heroTag: 'miUbicacion',
                  mini: true,
                  onPressed: _cargandoUbicacion ? null : _cargarMiUbicacion,
                  tooltip: 'Mi ubicación actual',
                  backgroundColor: Colors.white,
                  child: _cargandoUbicacion
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),

                // Zoom in
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black87),
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
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}