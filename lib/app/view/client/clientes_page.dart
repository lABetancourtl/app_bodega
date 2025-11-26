import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/view/client/crear_cliente_page.dart';
import 'package:app_bodega/app/view/client/editar_cliente_page.dart';
import 'package:flutter/material.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<ClienteModel> clientes = [];
  List<ClienteModel> clientesFiltrados = [];
  String? _rutaSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  void _cargarClientes() async {
    final clientesCargados = await _dbHelper.obtenerClientes();
    setState(() {
      clientes = clientesCargados;
      _filtrarClientes('');
    });
  }

  void _filtrarClientes(String query) {
    setState(() {
      clientesFiltrados = clientes.where((cliente) {
        // Filtrar por búsqueda
        final coincideBusqueda = query.isEmpty ||
            cliente.nombre.toLowerCase().contains(query.toLowerCase()) ||
            cliente.nombreNegocio.toLowerCase().contains(query.toLowerCase());

        // Filtrar por ruta
        final coincideRuta = _rutaSeleccionada == null ||
            cliente.ruta.toString().split('.').last == _rutaSeleccionada;

        return coincideBusqueda && coincideRuta;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _searchController,
              onChanged: _filtrarClientes,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('Todas'),
                    selected: _rutaSeleccionada == null,
                    onSelected: (selected) {
                      setState(() {
                        _rutaSeleccionada = null;
                        _filtrarClientes(_searchController.text);
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: _rutaSeleccionada == null ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('Ruta 1'),
                    selected: _rutaSeleccionada == 'ruta1',
                    onSelected: (selected) {
                      setState(() {
                        _rutaSeleccionada = 'ruta1';
                        _filtrarClientes(_searchController.text);
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: _rutaSeleccionada == 'ruta1' ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('Ruta 2'),
                    selected: _rutaSeleccionada == 'ruta2',
                    onSelected: (selected) {
                      setState(() {
                        _rutaSeleccionada = 'ruta2';
                        _filtrarClientes(_searchController.text);
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: _rutaSeleccionada == 'ruta2' ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('Ruta 3'),
                    selected: _rutaSeleccionada == 'ruta3',
                    onSelected: (selected) {
                      setState(() {
                        _rutaSeleccionada = 'ruta3';
                        _filtrarClientes(_searchController.text);
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: _rutaSeleccionada == 'ruta3' ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de clientes
          Expanded(
            child: clientesFiltrados.isEmpty
                ? Column(
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
            )
                : ListView.builder(
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
                        Text(cliente.nombreNegocio),
                        Text(
                          cliente.direccion,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Ruta: ${cliente.ruta.toString().split('.').last.toUpperCase()}',
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
                        await _dbHelper.actualizarCliente(clienteActualizado);
                        _cargarClientes();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cliente ${clienteActualizado.nombre} actualizado')),
                        );
                      }
                    },
                  ),
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
            await _dbHelper.insertarCliente(nuevoCliente);
            _cargarClientes();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cliente ${nuevoCliente.nombre} agregado')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}