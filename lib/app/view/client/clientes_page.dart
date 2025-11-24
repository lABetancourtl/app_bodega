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
        title: const Text('Clientes'),
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