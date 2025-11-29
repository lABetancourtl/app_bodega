import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/cache_manager.dart';
import 'package:app_bodega/app/view/client/crear_cliente_page.dart';
import 'package:app_bodega/app/view/client/editar_cliente_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============= STATE NOTIFIER PARA FILTROS =============
class FiltrosState {
  final String? rutaSeleccionada;
  final String searchQuery;

  FiltrosState({
    this.rutaSeleccionada,
    this.searchQuery = '',
  });

  FiltrosState copyWith({
    String? rutaSeleccionada,
    String? searchQuery,
  }) {
    return FiltrosState(
      rutaSeleccionada: rutaSeleccionada ?? this.rutaSeleccionada,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FiltrosNotifier extends StateNotifier<FiltrosState> {
  FiltrosNotifier() : super(FiltrosState());

  void setRuta(String? ruta) {
    state = state.copyWith(rutaSeleccionada: ruta);
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

// ============= PROVIDER PARA CLIENTES FILTRADOS =============
final clientesFiltradosProvider = Provider<List<ClienteModel>>((ref) {
  final clientesAsync = ref.watch(clientesProvider);
  final filtros = ref.watch(filtrosProvider);

  return clientesAsync.whenData((clientes) {
    return clientes.where((cliente) {
      // Filtrar por búsqueda
      final coincideBusqueda = filtros.searchQuery.isEmpty ||
          cliente.nombre.toLowerCase().contains(filtros.searchQuery.toLowerCase()) ||
          (cliente.nombreNegocio?.toLowerCase().contains(filtros.searchQuery.toLowerCase()) ?? false);

      // Filtrar por ruta
      final coincideRuta = filtros.rutaSeleccionada == null ||
          (cliente.ruta?.toString().split('.').last == filtros.rutaSeleccionada);

      return coincideBusqueda && coincideRuta;
    }).toList();
  }).maybeWhen(
    data: (data) => data,
    orElse: () => [],
  );
});

// ============= PÁGINA =============
class ClientesPage extends ConsumerWidget {
  const ClientesPage({super.key});

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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                        style: TextStyle(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = clientesFiltrados[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.store, color: Colors.blue),
                        title: Text(
                          cliente.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cliente.nombreNegocio ?? 'Sin negocio'),
                            Text(
                              cliente.direccion ?? 'Sin dirección',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Ruta: ${cliente.ruta?.toString().split('.').last.toUpperCase() ?? 'Sin ruta'}',
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final clienteActualizado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditarClientePage(cliente: cliente),
                            ),
                          );

                          if (clienteActualizado != null) {
                            try {
                              await dbHelper.actualizarCliente(clienteActualizado);
                              CacheHelper.invalidarClientes(ref);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cliente ${clienteActualizado.nombre} actualizado'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
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
              ref.invalidate(clientesProvider); // ✅ CORRECTO - Era ref.invalidate(nuevoCliente)

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cliente ${nuevoCliente.nombre} agregado')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
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
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

final dbHelper = DatabaseHelper();