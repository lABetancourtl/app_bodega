import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';

import 'seleccionar_cliente_page.dart';

class CrearFacturaPage extends StatefulWidget {
  const CrearFacturaPage({super.key});

  @override
  State<CrearFacturaPage> createState() => _CrearFacturaPageState();
}

class _CrearFacturaPageState extends State<CrearFacturaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  ClienteModel? clienteSeleccionado;
  List<ItemFacturaModel> items = [];

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  void _seleccionarCliente() async {
    final cliente = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SeleccionarClientePage()),
    );

    if (cliente != null) {
      setState(() {
        clienteSeleccionado = cliente;
      });
    }
  }

  void _agregarProducto() async {
    if (clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un cliente primero')),
      );
      return;
    }

    final nuevoItem = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AgregarProductoFacturaPage(),
      ),
    );

    if (nuevoItem != null) {
      setState(() {
        items.add(nuevoItem);
      });
    }
  }

  void _eliminarProducto(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    double total = items.fold(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Factura'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Seleccionar Cliente
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: _seleccionarCliente,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cliente',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              clienteSeleccionado?.nombre ?? 'Selecciona un cliente',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ),

              // Lista de productos agregados
              Expanded(
                child: items.isEmpty
                    ? const Center(
                  child: Text('No hay productos agregados'),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.local_drink, color: Colors.blue),
                        title: Text(item.nombreProducto),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.tieneSabores)
                              Text(
                                'Sabores: ${item.cantidadPorSabor.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
                                style: const TextStyle(fontSize: 12),
                              )
                            else
                              Text('Cantidad: ${item.cantidadTotal}'),
                            Text(
                              'Subtotal: \$${_formatearPrecio(item.subtotal)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarProducto(index),
                        ),
                      ),
                    );
                  },
                ),
              ),

              //Total
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 +
                      MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_formatearPrecio(total)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              )

            ],
          ),

          // Botón flotante posicionado arriba del total
          Positioned(
            right: 16,
            bottom: 74 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom, // Ajusta esta altura según necesites
            child: FloatingActionButton(
              onPressed: _agregarProducto,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}