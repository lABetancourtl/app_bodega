import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/cache_manager.dart';
import 'package:app_bodega/app/view/client/crear_cliente_page.dart';
import 'package:app_bodega/app/view/client/editar_cliente_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'historial_facturas_cliente_page.dart';

// ============= STATE NOTIFIER PARA FILTROS =============
class FiltrosState {
  final int rutaIndex; // Cambiado de String? a int para manejar índices
  final String searchQuery;

  FiltrosState({this.rutaIndex = 0, this.searchQuery = ''});

  FiltrosState copyWith({
    int? rutaIndex,
    String? searchQuery,
  }) {
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

final filtrosProvider = StateNotifierProvider<FiltrosNotifier, FiltrosState>((
    ref,
    ) {
  return FiltrosNotifier();
});

// ============= PROVIDERS =============
final clientesProvider = FutureProvider<List<ClienteModel>>((ref) async {
  final dbHelper = DatabaseHelper();
  return await dbHelper.obtenerClientes();
});

// Lista de rutas disponibles (incluye "Todas")
const List<Map<String, String?>> rutasDisponibles = [
  {'label': 'Todas', 'value': null},
  {'label': 'Ruta 1', 'value': 'ruta1'},
  {'label': 'Ruta 2', 'value': 'ruta2'},
  {'label': 'Ruta 3', 'value': 'ruta3'},
];

// ============= PROVIDER PARA CLIENTES FILTRADOS =============
final clientesFiltradosProvider = Provider<List<ClienteModel>>((ref) {
  final clientesAsync = ref.watch(clientesProvider);
  final filtros = ref.watch(filtrosProvider);
  final rutaSeleccionada = rutasDisponibles[filtros.rutaIndex]['value'];

  return clientesAsync
      .whenData((clientes) {
    return clientes.where((cliente) {
      // Filtrar por búsqueda
      final coincideBusqueda =
          filtros.searchQuery.isEmpty ||
              cliente.nombre.toLowerCase().contains(
                filtros.searchQuery.toLowerCase(),
              ) ||
              (cliente.nombreNegocio?.toLowerCase().contains(
                filtros.searchQuery.toLowerCase(),
              ) ??
                  false);

      // Filtrar por ruta
      final coincideRuta =
          rutaSeleccionada == null ||
              (cliente.ruta?.toString().split('.').last == rutaSeleccionada);

      return coincideBusqueda && coincideRuta;
    }).toList();
  })
      .maybeWhen(data: (data) => data, orElse: () => []);
});

// ============= PÁGINA =============
class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _mostrarOpcionesCliente(
      BuildContext context,
      ClienteModel cliente,
      ) {
    final dbHelper = DatabaseHelper();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 4),
                  Text(
                    cliente.nombre,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    cliente.direccion,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar cliente'),
              onTap: () async {
                Navigator.pop(sheetContext);

                final clienteActualizado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditarClientePage(cliente: cliente),
                  ),
                );

                if (clienteActualizado != null) {
                  try {
                    await dbHelper.actualizarCliente(clienteActualizado);
                    ref.invalidate(clientesProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cliente ${clienteActualizado.nombre} actualizado',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial de facturas'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HistorialFacturasClientePage(cliente: cliente),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar cliente',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmarEliminarCliente(context, cliente);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCliente(
      BuildContext context,
      ClienteModel cliente,
      ) {
    final dbHelper = DatabaseHelper();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${cliente.nombre}?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await dbHelper.eliminarCliente(cliente.id!);
                ref.invalidate(clientesProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cliente ${cliente.nombre} eliminado'),
                      backgroundColor: Colors.black45,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _construirListaClientes(List<ClienteModel> clientesFiltrados) {
    if (clientesFiltrados.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay clientes',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primer cliente',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: clientesFiltrados.length,
      itemBuilder: (context, index) {
        final cliente = clientesFiltrados[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: ListTile(
            leading: const Icon(Icons.store, color: Colors.blue),
            title: Text(
              cliente.nombreNegocio,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nombre ?? 'Sin nombre',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  cliente.direccion ?? 'Sin direccion',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ruta: ${cliente.ruta?.toString().split('.').last.toUpperCase() ?? 'Sin ruta'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _mostrarOpcionesCliente(context, cliente),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesProvider);
    final filtros = ref.watch(filtrosProvider);
    final dbHelper = DatabaseHelper();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clientes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                ref.read(filtrosProvider.notifier).setSearchQuery(value);
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o negocio',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Fila de rutas con indicador
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: rutasDisponibles.length,
                    itemBuilder: (context, index) {
                      final ruta = rutasDisponibles[index];
                      final isSelected = filtros.rutaIndex == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(ruta['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(filtrosProvider.notifier).setRutaIndex(index);
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // PageView con lista de clientes
          Expanded(
            child: clientesAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando clientes...'),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $err'),
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
                    final clientesFiltrados = ref.watch(clientesFiltradosProvider);
                    return _construirListaClientes(clientesFiltrados);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final nuevoCliente = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CrearClientePage()),
          );

          if (nuevoCliente != null) {
            try {
              await dbHelper.insertarCliente(nuevoCliente);
              ref.invalidate(clientesProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cliente ${nuevoCliente.nombre} agregado'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}