import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_bodega/app/theme/app_colors.dart';
import '../../providers/cache_providers.dart'; // ✅ NUEVO

class SeleccionarClientePage extends ConsumerStatefulWidget {
  const SeleccionarClientePage({super.key});

  @override
  ConsumerState<SeleccionarClientePage> createState() => _SeleccionarClientePageState();
}

class _SeleccionarClientePageState extends ConsumerState<SeleccionarClientePage> {
  final TextEditingController _searchController = TextEditingController();
  String? _rutaSeleccionada;

  final List<Map<String, String?>> rutasDisponibles = [
    {'label': 'Todas', 'value': null},
    {'label': 'Ruta 1', 'value': 'ruta1'},
    {'label': 'Ruta 2', 'value': 'ruta2'},
    {'label': 'Ruta 3', 'value': 'ruta3'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClienteModel> _filtrarClientes(List<ClienteModel> clientes, String query) {
    return clientes.where((cliente) {
      final coincideBusqueda = query.isEmpty ||
          cliente.nombre.toLowerCase().contains(query.toLowerCase()) ||
          cliente.direccion.toLowerCase().contains(query.toLowerCase()) ||
          cliente.nombreNegocio.toLowerCase().contains(query.toLowerCase());

      final coincideRuta = _rutaSeleccionada == null ||
          cliente.ruta.toString().split('.').last == _rutaSeleccionada;

      return coincideBusqueda && coincideRuta;
    }).toList();
  }

  void _mostrarSelectorRutas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) => Column(
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
                  child: const Icon(Icons.route, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filtrar por Ruta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rutasDisponibles.map((ruta) {
            final isSelected = ruta['value'] == _rutaSeleccionada;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: AppColors.accent, width: 2) : null,
                ),
                child: Center(
                  child: Icon(
                    ruta['value'] == null ? Icons.all_inclusive : Icons.route,
                    color: isSelected ? AppColors.accent : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              title: Text(
                ruta['label']!,
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
                  _rutaSeleccionada = ruta['value'];
                });
              },
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRouteSelector() {
    final rutaActual = rutasDisponibles.firstWhere(
          (r) => r['value'] == _rutaSeleccionada,
      orElse: () => rutasDisponibles[0],
    );

    return GestureDetector(
      onTap: _mostrarSelectorRutas,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Icon(Icons.route, color: Colors.white, size: 14)),
            ),
            const SizedBox(width: 10),
            Text(
              rutaActual['label']!,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Seleccionar Cliente',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtro de ruta
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: Column(
              children: [
                // Buscador
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                // Selector de ruta y contador
                Row(
                  children: [
                    _buildRouteSelector(),
                    const Spacer(),
                    clientesAsync.when(
                      data: (clientes) {
                        final filtrados = _filtrarClientes(clientes, _searchController.text);
                        return Text(
                          '${filtrados.length} clientes',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de clientes
          Expanded(
            child: clientesAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Cargando clientes...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error: $err', style: const TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
              data: (clientes) {
                final clientesFiltrados = _filtrarClientes(clientes, _searchController.text);

                if (clientesFiltrados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.people_outline, size: 64, color: AppColors.primary.withOpacity(0.3)),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Sin resultados',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No se encontraron clientes',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = clientesFiltrados[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, cliente),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.store, color: AppColors.primary, size: 24),
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cliente.nombre,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        cliente.direccion,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cliente.ruta.toString().split('.').last.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}