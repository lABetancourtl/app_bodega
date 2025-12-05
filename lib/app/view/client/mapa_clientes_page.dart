import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _searchController = TextEditingController();
  LatLng? _miUbicacion;
  bool _cargandoUbicacion = false;
  Ruta? _filtroRuta;
  ClienteModel? _clienteSeleccionado;
  String _busqueda = '';
  bool _mostrarBusqueda = false;
  final Set<String> _clientesVisitadosHoy = {};

  @override
  void initState() {
    super.initState();
    _cargarMiUbicacion();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarMiUbicacion() async {
    setState(() => _cargandoUbicacion = true);

    final locationService = LocationService();
    final position = await locationService.obtenerUbicacionActual();

    if (position != null && mounted) {
      setState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_miUbicacion!, 13.0);
    }

    setState(() => _cargandoUbicacion = false);
  }

  List<ClienteModel> get clientesFiltrados {
    final conUbicacion = widget.clientes
        .where((c) => c.latitud != null && c.longitud != null);

    var filtrados = conUbicacion;

    // Filtro por ruta
    if (_filtroRuta != null) {
      filtrados = filtrados.where((c) => c.ruta == _filtroRuta);
    }

    // Filtro por búsqueda
    if (_busqueda.isNotEmpty) {
      filtrados = filtrados.where((c) =>
      c.nombreNegocio.toLowerCase().contains(_busqueda.toLowerCase()) ||
          c.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          c.direccion.toLowerCase().contains(_busqueda.toLowerCase()));
    }

    return filtrados.toList();
  }

  List<Marker> _construirMarcadores() {
    final marcadores = <Marker>[];

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

    for (final cliente in clientesFiltrados) {
      if (cliente.latitud != null && cliente.longitud != null) {
        final esSeleccionado = _clienteSeleccionado?.id == cliente.id;
        final fueVisitado = _clientesVisitadosHoy.contains(cliente.id);

        marcadores.add(
          Marker(
            point: LatLng(cliente.latitud!, cliente.longitud!),
            width: 100,
            height: 120,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _mostrarInfoCliente(cliente),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClientesPulseMarker(
                    nombre: cliente.nombreNegocio,
                    color: _getColorRuta(cliente.ruta),
                    esSeleccionado: esSeleccionado,
                  ),
                  // Indicador de visita
                  if (fueVisitado)
                    Positioned(
                      top: -5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
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

  // NUEVA FUNCIÓN: Navegar al cliente
  Future<void> _navegarACliente(ClienteModel cliente) async {
    if (cliente.latitud == null || cliente.longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene ubicación')),
      );
      return;
    }

    // Mostrar opciones de navegación
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text('Google Maps'),
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${cliente.latitud},${cliente.longitud}',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.orange),
              title: const Text('Waze'),
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse(
                  'https://waze.com/ul?ll=${cliente.latitud},${cliente.longitud}&navigate=yes',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // NUEVA FUNCIÓN: Optimizar ruta
  void _optimizarRuta() {
    if (_miUbicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitamos tu ubicación para optimizar la ruta'),
        ),
      );
      return;
    }

    final clientesConDistancia = clientesFiltrados.map((cliente) {
      final distancia = _calcularDistancia(cliente);
      return {'cliente': cliente, 'distancia': distancia};
    }).toList();

    // Ordenar por distancia
    clientesConDistancia.sort((a, b) =>
        (a['distancia'] as double).compareTo(b['distancia'] as double));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text(
                      'Ruta Optimizada',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${clientesConDistancia.length} clientes',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Ordenados del más cercano al más lejano',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
              const Divider(height: 24),
              // Lista
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: clientesConDistancia.length,
                  itemBuilder: (context, index) {
                    final item = clientesConDistancia[index];
                    final cliente = item['cliente'] as ClienteModel;
                    final distancia = item['distancia'] as double;
                    final fueVisitado = _clientesVisitadosHoy.contains(cliente.id);

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getColorRuta(cliente.ruta),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (fueVisitado)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        cliente.nombreNegocio,
                        style: TextStyle(
                          decoration: fueVisitado
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        '${distancia.toStringAsFixed(0)} metros',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.location_on, size: 20),
                            onPressed: () {
                              Navigator.pop(context);
                              _mostrarInfoCliente(cliente);
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              fueVisitado ? Icons.undo : Icons.check_circle_outline,
                              size: 20,
                              color: fueVisitado ? Colors.orange : Colors.green,
                            ),
                            onPressed: () {
                              setState(() {
                                if (fueVisitado) {
                                  _clientesVisitadosHoy.remove(cliente.id);
                                } else {
                                  _clientesVisitadosHoy.add(cliente.id!);
                                }
                              });
                              Navigator.pop(context);
                              _optimizarRuta(); // Recargar el modal
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NUEVA FUNCIÓN: Centrar en todos los clientes
  void _centrarEnTodosLosClientes() {
    final clientes = clientesFiltrados;
    if (clientes.isEmpty) return;

    double minLat = clientes.first.latitud!;
    double maxLat = clientes.first.latitud!;
    double minLon = clientes.first.longitud!;
    double maxLon = clientes.first.longitud!;

    for (final cliente in clientes) {
      if (cliente.latitud! < minLat) minLat = cliente.latitud!;
      if (cliente.latitud! > maxLat) maxLat = cliente.latitud!;
      if (cliente.longitud! < minLon) minLon = cliente.longitud!;
      if (cliente.longitud! > maxLon) maxLon = cliente.longitud!;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLon + maxLon) / 2,
    );

    _mapController.move(center, 13.0);
  }

  void _mostrarInfoCliente(ClienteModel cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
    });

    _mapController.move(
      LatLng(cliente.latitud!, cliente.longitud!),
      16.0,
    );

    final fueVisitado = _clientesVisitadosHoy.contains(cliente.id);

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
                  // Indicador de visita
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: fueVisitado ? Colors.green : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          fueVisitado ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: fueVisitado ? Colors.white : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fueVisitado ? 'Visitado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 12,
                            color: fueVisitado ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

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

              const SizedBox(height: 20),

              // Botones de acción mejorados
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (fueVisitado) {
                            _clientesVisitadosHoy.remove(cliente.id);
                          } else {
                            _clientesVisitadosHoy.add(cliente.id!);
                          }
                        });
                        Navigator.pop(context);
                      },
                      icon: Icon(fueVisitado ? Icons.undo : Icons.check),
                      label: Text(fueVisitado ? 'Desmarcar' : 'Marcar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: fueVisitado ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navegarACliente(cliente);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Navegar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
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
    final clientesVisitados = _clientesVisitadosHoy.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Clientes'),
        centerTitle: true,
        actions: [
          // Búsqueda
          IconButton(
            icon: Icon(_mostrarBusqueda ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _mostrarBusqueda = !_mostrarBusqueda;
                if (!_mostrarBusqueda) {
                  _busqueda = '';
                  _searchController.clear();
                }
              });
            },
          ),
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
          // Menú de opciones
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'optimizar':
                  _optimizarRuta();
                  break;
                case 'centrar':
                  _centrarEnTodosLosClientes();
                  break;
                case 'limpiar':
                  setState(() {
                    _clientesVisitadosHoy.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Visitas limpiadas'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'optimizar',
                child: Row(
                  children: [
                    Icon(Icons.route, size: 20),
                    SizedBox(width: 12),
                    Text('Optimizar ruta'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'centrar',
                child: Row(
                  children: [
                    Icon(Icons.center_focus_strong, size: 20),
                    SizedBox(width: 12),
                    Text('Centrar todo'),
                  ],
                ),
              ),
              if (clientesVisitados > 0)
                const PopupMenuItem(
                  value: 'limpiar',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, size: 20),
                      SizedBox(width: 12),
                      Text('Limpiar visitas'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
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

          // Barra de búsqueda
          if (_mostrarBusqueda)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar cliente...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _busqueda = value);
                  },
                ),
              ),
            ),

          // Panel de información
          if (!_mostrarBusqueda)
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            Icons.location_on,
                            '$clientesConUbicacion ubicados',
                            Colors.green,
                          ),
                          if (clientesSinUbicacion > 0)
                            _buildChip(
                              Icons.location_off,
                              '$clientesSinUbicacion sin ubicar',
                              Colors.orange,
                            ),
                          if (clientesVisitados > 0)
                            _buildChip(
                              Icons.check_circle,
                              '$clientesVisitados visitados',
                              Colors.blue,
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

          // Controles de mapa
          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.my_location, color: Colors.black),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),

          // Botón de optimizar ruta
          Positioned(
            bottom: 20,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'optimizarRuta',
              onPressed: _optimizarRuta,
              backgroundColor: Colors.blue,
              icon: const Icon(Icons.route, color: Colors.white),
              label: const Text(
                'Optimizar Ruta',
                style: TextStyle(color: Colors.white),
              ),
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