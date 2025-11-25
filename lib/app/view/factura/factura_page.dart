import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/service/pdf_service.dart';
import 'package:app_bodega/app/view/factura/crear_factura_page.dart';
import 'package:app_bodega/app/view/factura/editar_factura_page.dart';
import 'package:flutter/material.dart';

class FacturaPage extends StatefulWidget {
  const FacturaPage({super.key});

  @override
  State<FacturaPage> createState() => _FacturaPageState();
}

class _FacturaPageState extends State<FacturaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<FacturaModel> facturas = [];

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  void _cargarFacturas() async {
    final facturasCargadas = await _dbHelper.obtenerFacturas();
    setState(() {
      facturas = facturasCargadas;
    });
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  void _mostrarMenuFlotante() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Factura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Factura a Clientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CrearFacturaPage(),
                  ),
                ).then((_) {
                  _cargarFacturas();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Limpia'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Factura limpia')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editarFactura(FacturaModel factura) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarFacturaPage(factura: factura),
      ),
    ).then((_) {
      _cargarFacturas();
    });
  }

  void _eliminarFactura(FacturaModel factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Factura'),
        content: Text('¿Estás seguro de que deseas eliminar la factura de ${factura.nombreCliente}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _dbHelper.eliminarFactura(factura.id!);
              _cargarFacturas();
              Navigator.pop(context);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Factura eliminada')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _descargarFactura(FacturaModel factura) async {
    try {
      await PdfService.generarYDescargarPDF(factura);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturas'),
      ),
      body: facturas.isEmpty
          ? const Center(
        child: Text('No hay facturas generadas'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: facturas.length,
        itemBuilder: (context, index) {
          final factura = facturas[index];
          final total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.receipt, color: Colors.blue),
              title: Text(
                factura.nombreCliente,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha: ${factura.fecha.day}/${factura.fecha.month}/${factura.fecha.year}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Productos: ${factura.items.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Total: \$${_formatearPrecio(total)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(factura.nombreCliente),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _editarFactura(factura);
                          },
                          child: const Text('Editar'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _descargarFactura(factura);
                          },
                          child: const Text('Descargar'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _eliminarFactura(factura);
                          },
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarMenuFlotante,
        child: const Icon(Icons.add),
      ),
    );
  }
}