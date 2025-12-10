import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/clientes_pulse_market.dart';
import '../../widgets/pulse_marker.dart';

// ============= COLORES DEL TEMA =============
class AppColors {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2E5077);
  static const Color accent = Color(0xFF00B894);
  static const Color accentLight = Color(0xFFE8F8F5);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

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
      _mapController.move(_miUbicacion!, 13.0);
    }

    setState(() => _cargandoUbicacion = false);
  }

  List<ClienteModel> get clientesFiltrados {
    final conUbicacion = widget.clientes.where((c) => c.latitud != null && c.longitud != null);

    var filtrados = conUbicacion;

    if (_filtroRuta != null) {
      filtrados = filtrados.where((c) => c.ruta == _filtroRuta);
    }

    if (_busqueda.isNotEmpty) {
      filtrados = filtrados.where((c) =>
      (c.nombreNegocio?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false) ||
          c.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          (c.direccion?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false));
    }

    return filtrados.toList();
  }

  Color _getColorRuta(Ruta? ruta) {
    if (ruta == null) return AppColors.textSecondary;

    switch (ruta) {
      case Ruta.ruta1:
        return Colors.orange;
      case Ruta.ruta2:
        return AppColors.error;
      case Ruta.ruta3:
        return Colors.deepPurple;
      default:
        return AppColors.textSecondary;
    }
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
            width: 80,
            height: 90,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _mostrarInfoCliente(cliente),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  ClientesPulseMarker(
                    nombre: cliente.nombreNegocio ?? cliente.nombre,
                    color: _getColorRuta(cliente.ruta),
                    esSeleccionado: esSeleccionado,
                  ),
                  if (fueVisitado)
                    Positioned(
                      top: 0,
                      right: 15,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 11),
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

  void _mostrarFiltroRutas() {
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.filter_list, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Filtrar por Ruta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildFiltroRutaItem(null, 'Todas las rutas', Icons.all_inclusive, sheetContext),
            _buildFiltroRutaItem(Ruta.ruta1, 'Ruta 1', Icons.route, sheetContext, color: Colors.orange),
            _buildFiltroRutaItem(Ruta.ruta2, 'Ruta 2', Icons.route, sheetContext, color: AppColors.error),
            _buildFiltroRutaItem(Ruta.ruta3, 'Ruta 3', Icons.route, sheetContext, color: Colors.deepPurple),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroRutaItem(Ruta? ruta, String label, IconData icon, BuildContext sheetContext, {Color? color}) {
    final isSelected = _filtroRuta == ruta;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.accent, width: 2) : null,
        ),
        child: Icon(icon, color: isSelected ? AppColors.accent : (color ?? AppColors.primary), size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      )
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      onTap: () {
        Navigator.pop(sheetContext);
        setState(() {
          _filtroRuta = ruta;
        });
      },
    );
  }

  Future<void> _navegarACliente(ClienteModel cliente) async {
    if (cliente.latitud == null || cliente.longitud == null) {
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
                        const Text('Navegar a', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          cliente.nombreNegocio ?? cliente.nombre,
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.map, color: Colors.blue, size: 24),
              ),
              title: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${cliente.latitud},${cliente.longitud}',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.navigation, color: Colors.orange, size: 24),
              ),
              title: const Text('Waze', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                final url = Uri.parse(
                  'https://waze.com/ul?ll=${cliente.latitud},${cliente.longitud}&navigate=yes',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _optimizarRuta() {
    if (_miUbicacion == null) {
      _mostrarSnackBar('Necesitamos tu ubicación para optimizar la ruta', isError: true);
      return;
    }

    final clientesConDistancia = clientesFiltrados.map((cliente) {
      final distancia = _calcularDistancia(cliente);
      return {'cliente': cliente, 'distancia': distancia};
    }).toList();

    clientesConDistancia.sort((a, b) => (a['distancia'] as double).compareTo(b['distancia'] as double));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ruta Optimizada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('Del más cercano al más lejano', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${clientesConDistancia.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: clientesConDistancia.length,
                itemBuilder: (context, index) {
                  final item = clientesConDistancia[index];
                  final cliente = item['cliente'] as ClienteModel;
                  final distancia = item['distancia'] as double;
                  final fueVisitado = _clientesVisitadosHoy.contains(cliente.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: fueVisitado ? AppColors.accent : AppColors.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getColorRuta(cliente.ruta),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (fueVisitado)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 10),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        cliente.nombreNegocio ?? cliente.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          decoration: fueVisitado ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        distancia < 1000 ? '${distancia.toStringAsFixed(0)} m' : '${(distancia / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.location_on, size: 20, color: AppColors.primary),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _mostrarInfoCliente(cliente);
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              fueVisitado ? Icons.undo : Icons.check_circle_outline,
                              size: 20,
                              color: fueVisitado ? AppColors.warning : AppColors.accent,
                            ),
                            onPressed: () {
                              setState(() {
                                if (fueVisitado) {
                                  _clientesVisitadosHoy.remove(cliente.id);
                                } else {
                                  _clientesVisitadosHoy.add(cliente.id!);
                                }
                              });
                              Navigator.pop(sheetContext);
                              _optimizarRuta();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    _mapController.move(center, 13.0);
  }

  void _mostrarInfoCliente(ClienteModel cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
    });

    _mapController.move(LatLng(cliente.latitud!, cliente.longitud!), 16.0);

    final fueVisitado = _clientesVisitadosHoy.contains(cliente.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Container(
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getColorRuta(cliente.ruta),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombreNegocio ?? 'Sin negocio',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (cliente.ruta != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getColorRuta(cliente.ruta).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cliente.ruta.toString().split('.').last.toUpperCase(),
                              style: TextStyle(fontSize: 10, color: _getColorRuta(cliente.ruta), fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: fueVisitado ? AppColors.accentLight : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: fueVisitado ? AppColors.accent : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          fueVisitado ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: fueVisitado ? AppColors.accent : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fueVisitado ? 'Visitado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 12,
                            color: fueVisitado ? AppColors.accent : AppColors.textSecondary,
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
              _buildInfoRow(Icons.location_on, 'Dirección', cliente.direccion ?? 'Sin dirección'),
              if (cliente.telefono != null && cliente.telefono!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, 'Teléfono', cliente.telefono!),
              ],
              if (_miUbicacion != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.social_distance,
                  'Distancia',
                  _calcularDistancia(cliente) < 1000
                      ? '${_calcularDistancia(cliente).toStringAsFixed(0)} m'
                      : '${(_calcularDistancia(cliente) / 1000).toStringAsFixed(2)} km',
                ),
              ],
              const SizedBox(height: 20),
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
                        Navigator.pop(sheetContext);
                      },
                      icon: Icon(
                        fueVisitado ? Icons.undo : Icons.check_circle,
                        size: 18,
                        color: fueVisitado ? AppColors.warning : AppColors.accent,
                      ),
                      label: Text(
                        fueVisitado ? 'Desmarcar' : 'Marcar Visitado',
                        style: TextStyle(color: fueVisitado ? AppColors.warning : AppColors.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: fueVisitado ? AppColors.warning : AppColors.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _navegarACliente(cliente);
                      },
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Navegar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildMapButton({
    required String heroTag,
    required IconData icon,
    String? tooltip,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isActive = false,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: isActive ? AppColors.primary : AppColors.surface,
      tooltip: tooltip,
      elevation: 2,
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : Icon(icon, size: 20, color: isActive ? Colors.white : AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: _mostrarBusqueda
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar cliente...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (value) {
            setState(() {
              _busqueda = value;
            });
          },
        )
            : const Text('Mapa de Clientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_mostrarBusqueda)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () {
                setState(() {
                  _mostrarBusqueda = false;
                  _searchController.clear();
                  _busqueda = '';
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textPrimary),
              tooltip: 'Buscar',
              onPressed: () {
                setState(() {
                  _mostrarBusqueda = true;
                });
              },
            ),
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.filter_list, color: AppColors.primary),
                  if (_filtroRuta != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filtrar por ruta',
              onPressed: _mostrarFiltroRutas,
            ),
            IconButton(
              icon: const Icon(Icons.route, color: AppColors.accent),
              tooltip: 'Optimizar ruta',
              onPressed: _optimizarRuta,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _miUbicacion ?? const LatLng(4.6097, -74.0817),
              initialZoom: 13,
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
              MarkerLayer(markers: _construirMarcadores()),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
                ],
              ),
            ],
          ),

          // Contador de clientes
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${clientesFiltrados.length} clientes',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (_clientesVisitadosHoy.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_clientesVisitadosHoy.length} visitados',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Controles del mapa
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapButton(
                  heroTag: 'verTodos',
                  icon: Icons.fit_screen,
                  tooltip: 'Ver todos los clientes',
                  onPressed: _centrarEnTodosLosClientes,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  heroTag: 'miUbicacion',
                  icon: Icons.my_location,
                  tooltip: 'Mi ubicación',
                  isLoading: _cargandoUbicacion,
                  onPressed: _cargandoUbicacion
                      ? null
                      : () {
                    if (_miUbicacion != null) {
                      _mapController.move(_miUbicacion!, 16.0);
                    } else {
                      _cargarMiUbicacion();
                    }
                  },
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
    );
  }
}