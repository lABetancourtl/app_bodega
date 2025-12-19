import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/view/client/crear_cliente_page.dart';
import 'package:app_bodega/app/view/client/editar_cliente_page.dart';
import 'package:app_bodega/app/view/client/view_ubicacion_cliente_page.dart';
import 'package:app_bodega/app/view/client/mapa_clientes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'historial_facturas_cliente_page.dart';
import 'package:app_bodega/app/theme/app_colors.dart';
import '../../providers/cache_providers.dart';


// ============= STATE NOTIFIER PARA FILTROS =============
class FiltrosState {
  final int rutaIndex;
  final String searchQuery;

  FiltrosState({this.rutaIndex = 0, this.searchQuery = ''});

  FiltrosState copyWith({int? rutaIndex, String? searchQuery}) {
    return FiltrosState(
      rutaIndex: rutaIndex ?? this.rutaIndex,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FiltrosNotifier extends StateNotifier<FiltrosState> {
  FiltrosNotifier() : super(FiltrosState());

  void setRutaIndex(int index) {
    state = state.copyWith(rutaIndex: index);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = FiltrosState();
  }
}

final filtrosProvider = StateNotifierProvider<FiltrosNotifier, FiltrosState>((ref) {
  return FiltrosNotifier();
});


final clientesPorRutaProvider = FutureProvider.family<List<ClienteModel>, String?>((ref, rutaValue) async {
  final clientesAsync = ref.watch(clientesProvider);

  return clientesAsync.whenData((clientes) {
    if (rutaValue == null) {
      return clientes;
    }
    return clientes.where((cliente) {
      return cliente.ruta?.toString().split('.').last == rutaValue;
    }).toList();
  }).value ?? [];
});

const List<Map<String, String?>> rutasDisponibles = [
  {'label': 'Todas', 'value': null},
  {'label': 'Ruta 1', 'value': 'ruta1'},
  {'label': 'Ruta 2', 'value': 'ruta2'},
  {'label': 'Ruta 3', 'value': 'ruta3'},
];

final clientesFiltradosProvider = Provider<List<ClienteModel>>((ref) {
  final filtros = ref.watch(filtrosProvider);
  final rutaSeleccionada = rutasDisponibles[filtros.rutaIndex]['value'];
  final clientesPorRuta = ref.watch(clientesPorRutaProvider(rutaSeleccionada));

  return clientesPorRuta.whenData((clientes) {
    return clientes.where((cliente) {
      final query = filtros.searchQuery.toLowerCase();
      final coincideBusqueda = filtros.searchQuery.isEmpty ||
          cliente.nombre.toLowerCase().contains(query) ||
          cliente.nombreNegocio.toLowerCase().contains(query) ||
          cliente.direccion.toLowerCase().contains(query);
      return coincideBusqueda;
    }).toList();
  }).maybeWhen(data: (data) => data, orElse: () => []);
});

// ============= PÁGINA =============
class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  // Selector de rutas desplegable
  void _mostrarSelectorRutas(BuildContext context) {
    final filtros = ref.read(filtrosProvider);

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
                  'Seleccionar Ruta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rutasDisponibles.asMap().entries.map((entry) {
            final index = entry.key;
            final ruta = entry.value;
            final isSelected = index == filtros.rutaIndex;

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
                    index == 0 ? Icons.all_inclusive : Icons.route,
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
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
                  : const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(filtrosProvider.notifier).setRutaIndex(index);
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRouteSelector() {
    final filtros = ref.watch(filtrosProvider);
    final rutaActual = rutasDisponibles[filtros.rutaIndex];

    return GestureDetector(
      onTap: () => _mostrarSelectorRutas(context),
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
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.route, color: Colors.white, size: 14),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              rutaActual['label']!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int totalPages, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${currentPage + 1}/$totalPages',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(
            totalPages > 5 ? 5 : totalPages,
                (index) {
              int dotIndex = index;
              if (totalPages > 5) {
                if (currentPage < 3) {
                  dotIndex = index;
                } else if (currentPage > totalPages - 3) {
                  dotIndex = totalPages - 5 + index;
                } else {
                  dotIndex = currentPage - 2 + index;
                }
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: dotIndex == currentPage ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotIndex == currentPage ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _mostrarOpcionesComunicacion(BuildContext context, ClienteModel cliente) {
    if (cliente.telefono == null || cliente.telefono!.isEmpty) {
      _mostrarSnackBar('Este cliente no tiene número de teléfono', isError: true);
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
              margin: const EdgeInsets.only(top: 12, bottom: 16),
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
                    child: const Icon(Icons.contact_phone, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombreNegocio ?? cliente.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          cliente.telefono!,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone, color: AppColors.primary, size: 20),
              ),
              title: const Text('Llamada telefónica'),
              subtitle: const Text('Abrir marcador', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _realizarLlamada(context, cliente.telefono!);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat, color: AppColors.primary, size: 20),
              ),
              title: const Text('WhatsApp'),
              subtitle: const Text('Abrir chat', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _abrirWhatsApp(context, cliente.telefono!);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _realizarLlamada(BuildContext context, String telefono) async {
    final telefonoLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri telUri = Uri(scheme: 'tel', path: telefonoLimpio);

    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        if (context.mounted) {
          _mostrarSnackBar('No se puede realizar la llamada', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _mostrarSnackBar('Error al realizar la llamada: $e', isError: true);
      }
    }
  }

  Future<void> _abrirWhatsApp(BuildContext context, String telefono) async {
    String telefonoLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    if (!telefonoLimpio.startsWith('+')) {
      if (telefonoLimpio.startsWith('57')) {
        telefonoLimpio = '+$telefonoLimpio';
      } else {
        telefonoLimpio = '+57$telefonoLimpio';
      }
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$telefonoLimpio');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _mostrarSnackBar('No se puede abrir WhatsApp', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _mostrarSnackBar('Error al abrir WhatsApp: $e', isError: true);
      }
    }
  }

  void _mostrarOpcionesCliente(BuildContext context, ClienteModel cliente) {
    final dbHelper = DatabaseHelper();
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
              margin: const EdgeInsets.only(top: 12, bottom: 16),
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (cliente.nombreNegocio ?? cliente.nombre).substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombreNegocio ?? 'Sin negocio',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          cliente.nombre,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        if (cliente.direccion != null)
                          Text(
                            cliente.direccion!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.contact_phone, color: AppColors.primary, size: 20),
                ),
                title: const Text('Comunicar'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _mostrarOpcionesComunicacion(context, cliente);
                },
              ),
            if (cliente.latitud != null && cliente.longitud != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
                ),
                title: const Text('Ver en mapa'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ViewUbicacionClientePage(cliente: cliente)),
                  );
                },
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
              ),
              title: const Text('Editar cliente'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final clienteActualizado = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditarClientePage(cliente: cliente)),
                );

                if (clienteActualizado != null) {
                  try {
                    await dbHelper.actualizarCliente(clienteActualizado);
                    await CacheHelper.invalidarClientes(ref);

                    if (context.mounted) {
                      _mostrarSnackBar('Cliente actualizado', isSuccess: true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      _mostrarSnackBar('Error: $e', isError: true);
                    }
                  }
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history, color: AppColors.primary, size: 20),
              ),
              title: const Text('Historial de facturas'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistorialFacturasClientePage(cliente: cliente)),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              ),
              title: const Text('Eliminar cliente', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmarEliminarCliente(context, cliente);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCliente(BuildContext context, ClienteModel cliente) {
    final dbHelper = DatabaseHelper();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Cliente'),
          ],
        ),
        content: Text('¿Eliminar a ${cliente.nombre}?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await dbHelper.eliminarCliente(cliente.id!);

                // ✅ Invalidar caché
                await CacheHelper.invalidarClientes(ref);

                if (context.mounted) {
                  _mostrarSnackBar('Cliente eliminado', isSuccess: true);
                }
              } catch (e) {
                if (context.mounted) {
                  _mostrarSnackBar('Error: $e', isError: true);
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _construirListaClientes(List<ClienteModel> clientesFiltrados) {
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
              'Sin clientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega tu primer cliente',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _crearCliente(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Agregar Cliente'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
              onTap: () => _mostrarOpcionesCliente(context, cliente),
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
                            cliente.nombreNegocio ?? 'Sin negocio',
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
                          if (cliente.direccion != null)
                            Text(
                              cliente.direccion!,
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
                        cliente.ruta?.toString().split('.').last.toUpperCase() ?? 'SIN RUTA',
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
  }

  void _crearCliente(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final nuevoCliente = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CrearClientePage()),
    );

    if (nuevoCliente != null) {
      try {
        await dbHelper.insertarCliente(nuevoCliente);
        await CacheHelper.invalidarClientes(ref);

        if (context.mounted) {
          _mostrarSnackBar('Cliente ${nuevoCliente.nombre} creado', isSuccess: true);
        }
      } catch (e) {
        if (context.mounted) {
          _mostrarSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  void _abrirMapaClientes() {
    final clientesAsync = ref.read(clientesProvider);

    clientesAsync.whenData((clientes) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MapaClientesPage(clientes: clientes)),
      );
    }).whenOrNull(
      error: (err, stack) {
        _mostrarSnackBar('Error al cargar clientes: $err', isError: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesProvider);
    final clientesFiltrados = ref.watch(clientesFiltradosProvider);
    final filtros = ref.watch(filtrosProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar clientes...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (value) {
            ref.read(filtrosProvider.notifier).setSearchQuery(value);
          },
        )
            : _buildRouteSelector(),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  ref.read(filtrosProvider.notifier).setSearchQuery('');
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textPrimary),
              tooltip: 'Buscar',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.primary),
              tooltip: 'Ver mapa',
              onPressed: _abrirMapaClientes,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'Nuevo cliente',
              onPressed: () => _crearCliente(context),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Indicador de página
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: _buildPageIndicator(rutasDisponibles.length, filtros.rutaIndex),
          ),
          // PageView para deslizar entre rutas
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(clientesProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (clientes) {
                return PageView.builder(
                  controller: _pageController,
                  itemCount: rutasDisponibles.length,
                  onPageChanged: (index) {
                    ref.read(filtrosProvider.notifier).setRutaIndex(index);
                  },
                  itemBuilder: (context, pageIndex) {
                    final rutaValue = rutasDisponibles[pageIndex]['value'];
                    final clientesDeRuta = rutaValue == null
                        ? clientes
                        : clientes.where((c) => c.ruta?.toString().split('.').last == rutaValue).toList();

                    // Aplicar búsqueda
                    final clientesBuscados = filtros.searchQuery.isEmpty
                        ? clientesDeRuta
                        : clientesDeRuta.where((c) =>
                        c.nombre.toLowerCase().contains(filtros.searchQuery.toLowerCase()) ||
                        c.direccion.toLowerCase().contains(filtros.searchQuery.toLowerCase()) ||
                        (c.nombreNegocio?.toLowerCase().contains(filtros.searchQuery.toLowerCase()) ?? false)
                    ).toList();

                    return _construirListaClientes(clientesBuscados);
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