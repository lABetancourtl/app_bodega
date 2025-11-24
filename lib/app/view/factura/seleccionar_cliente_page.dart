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

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  void _cargarClientes() async {
    final clientesCargados = await _dbHelper.obtenerClientes();
    setState(() {
      clientes = clientesCargados;
      clientesFiltrados = clientes;
    });
  }

  void _filtrarClientes(String query) {
    setState(() {
      if (query.isEmpty) {
        clientesFiltrados = clientes;
      } else {
        clientesFiltrados = clientes
            .where((cliente) =>
        cliente.nombre.toLowerCase().contains(query.toLowerCase()) ||
            cliente.nombreNegocio.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
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
                      cliente.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(cliente.nombreNegocio),
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