import 'package:app_bodega/app/view/factura/crear_factura_page.dart';
import 'package:flutter/material.dart';

class FacturaPage extends StatelessWidget {
  const FacturaPage({super.key});

  void _mostrarMenuFlotante(BuildContext context) {
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
                );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factura'),
      ),
      body: const Center(
        child: Text('Historial de facturas'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarMenuFlotante(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}