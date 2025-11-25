import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';

class EditarFacturaPage extends StatefulWidget {
  final FacturaModel factura;

  const EditarFacturaPage({super.key, required this.factura});

  @override
  State<EditarFacturaPage> createState() => _EditarFacturaPageState();
}

class _EditarFacturaPageState extends State<EditarFacturaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late List<ItemFacturaModel> items;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.factura.items);
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  void _agregarProducto() async {
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

  void _guardarCambios() async {
    final facturaActualizada = FacturaModel(
      id: widget.factura.id,
      clienteId: widget.factura.clienteId,
      nombreCliente: widget.factura.nombreCliente,
      fecha: widget.factura.fecha,
      items: items,
      estado: widget.factura.estado,
    );

    try {
      await _dbHelper.actualizarFactura(facturaActualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Factura actualizada para ${widget.factura.nombreCliente}')),
        );
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = items.fold(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Factura'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _guardarCambios,
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Información del cliente (no editable)
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                            widget.factura.nombreCliente,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fecha: ${widget.factura.fecha.day}/${widget.factura.fecha.month}/${widget.factura.fecha.year}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Icon(Icons.lock, color: Colors.grey),
                    ],
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
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${item.cantidadTotal}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        title: Text(item.nombreProducto),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.tieneSabores)
                              Text(
                                'Sabores: ${item.cantidadPorSabor.entries.where((e) => e.value > 0).map((e) => '${e.key} (${e.value})').join(', ')}',
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

              // Total
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
                      'Total: ',
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
              ),
            ],
          ),

          // Botón flotante posicionado arriba del total
          Positioned(
            right: 16,
            bottom: 74 +
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom,
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