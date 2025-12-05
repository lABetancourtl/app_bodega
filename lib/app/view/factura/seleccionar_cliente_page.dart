import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:flutter/material.dart';

class SeleccionarClientePage extends StatefulWidget {
  const SeleccionarClientePage({super.key});

  @override
  State<SeleccionarClientePage> createState() => _SeleccionarClientePageState();
}

class _SeleccionarClientePageState extends State<SeleccionarClientePage> {
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
            cliente.direccion.toLowerCase().contains(query.toLowerCase()) ||
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
        title: const Text('Seleccionar Cliente'),
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
                hintText: 'Buscar cliente',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
                ? const Center(
              child: Text('No hay clientes'),
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
                          cliente.ruta?.toString().split('.').last.toUpperCase() ?? 'Sin ruta',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context, cliente);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}