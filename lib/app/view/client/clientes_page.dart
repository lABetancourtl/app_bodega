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
  final String? rutaSeleccionada;
  final String searchQuery;

  FiltrosState({this.rutaSeleccionada, this.searchQuery = ''});

  FiltrosState copyWith({
    String? rutaSeleccionada,
    String? searchQuery,
    bool clearRuta = false, // ← nuevo parámetro
  }) {
    return FiltrosState(
      rutaSeleccionada: clearRuta
          ? null
          : rutaSeleccionada ?? this.rutaSeleccionada,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FiltrosNotifier extends StateNotifier<FiltrosState> {
  FiltrosNotifier() : super(FiltrosState());

  void setRuta(String? ruta) {
    if (ruta == null) {
      state = state.copyWith(clearRuta: true);
    } else {
      state = state.copyWith(rutaSeleccionada: ruta);
    }
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

// ============= PROVIDER PARA CLIENTES FILTRADOS =============
final clientesFiltradosProvider = Provider<List<ClienteModel>>((ref) {
  final clientesAsync = ref.watch(clientesProvider);
  final filtros = ref.watch(filtrosProvider);

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
              filtros.rutaSeleccionada == null ||
              (cliente.ruta?.toString().split('.').last ==
                  filtros.rutaSeleccionada);

          return coincideBusqueda && coincideRuta;
        }).toList();
      })
      .maybeWhen(data: (data) => data, orElse: () => []);
});

// ============= PÁGINA =============
class ClientesPage extends ConsumerWidget {
  const ClientesPage({super.key});

  void _mostrarOpcionesCliente(
    BuildContext context,
    WidgetRef ref,
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
                    style:  TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    cliente.direccion,
                    style:  TextStyle(
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
                _confirmarEliminarCliente(context, ref, cliente);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCliente(
    BuildContext context,
    WidgetRef ref,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesProvider);
    final clientesFiltrados = ref.watch(clientesFiltradosProvider);
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

          // Fila de rutas
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                _construirFiltroRuta(
                  ref,
                  'Todas',
                  null,
                  filtros.rutaSeleccionada == null,
                ),
                _construirFiltroRuta(
                  ref,
                  'Ruta 1',
                  'ruta1',
                  filtros.rutaSeleccionada == 'ruta1',
                ),
                _construirFiltroRuta(
                  ref,
                  'Ruta 2',
                  'ruta2',
                  filtros.rutaSeleccionada == 'ruta2',
                ),
                _construirFiltroRuta(
                  ref,
                  'Ruta 3',
                  'ruta3',
                  filtros.rutaSeleccionada == 'ruta3',
                ),
              ],
            ),
          ),

          // Lista de clientes
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
                              style:  TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            Text(
                              cliente.direccion ?? 'Sin direccion',
                              style:  TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold
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
                        onTap: () =>
                            _mostrarOpcionesCliente(context, ref, cliente),
                      ),
                    );
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

  Widget _construirFiltroRuta(
    WidgetRef ref,
    String label,
    String? ruta,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref.read(filtrosProvider.notifier).setRuta(ruta);
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }
}
