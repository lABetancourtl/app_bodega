import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/service/pdf_service.dart';
import 'package:app_bodega/app/view/factura/crear_factura_page.dart';
import 'package:app_bodega/app/view/factura/editar_factura_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class FacturaPage extends StatefulWidget {
  const FacturaPage({super.key});

  @override
  State<FacturaPage> createState() => _FacturaPageState();
}

class _FacturaPageState extends State<FacturaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<FacturaModel> facturas = [];
  List<FacturaModel> facturasFiltradas = [];
  DateTime? fechaSeleccionada;

  @override
  void initState() {
    super.initState();
    fechaSeleccionada = DateTime.now();
    _cargarFacturas();
  }

  void _cargarFacturas() async {
    final facturasCargadas = await _dbHelper.obtenerFacturas();
    setState(() {
      facturas = facturasCargadas;
      // Filtrar DESPUÉS de que se carguen las facturas
      _filtrarPorFecha(fechaSeleccionada!);
    });
  }

  void _filtrarPorFecha(DateTime fecha) {
    setState(() {
      fechaSeleccionada = fecha;
      facturasFiltradas = facturas.where((factura) {
        return factura.fecha.year == fecha.year &&
            factura.fecha.month == fecha.month &&
            factura.fecha.day == fecha.day;
      }).toList();
    });
  }

  void _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      _filtrarPorFecha(picked);
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  String _generarMensajeFactura(FacturaModel factura) {
    final total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final fecha = '${factura.fecha.day}/${factura.fecha.month}/${factura.fecha.year}';

    String mensaje = '*Factura de Bodega*\n\n';
    mensaje += '👤 *Cliente:* ${factura.nombreCliente}\n';
    if (factura.direccionCliente != null) {
      mensaje += '📍 *Dirección:* ${factura.direccionCliente}\n';
    }
    if (factura.negocioCliente != null) {
      mensaje += '🏪 *Negocio:* ${factura.negocioCliente}\n';
    }
    mensaje += '📅 *Fecha:* $fecha\n\n';

    mensaje += '*Productos:*\n';
    for (var item in factura.items) {
      mensaje += '• ${item.nombreProducto}\n';
      mensaje += '  Cantidad: ${item.cantidadTotal}\n';
      mensaje += '  Precio unitario: \$${_formatearPrecio(item.precioUnitario)}\n';
      mensaje += '  Subtotal: \$${_formatearPrecio(item.subtotal)}\n\n';
    }

    mensaje += '━━━━━━━━━━━━━━━━\n';
    mensaje += '*💰 TOTAL: \$${_formatearPrecio(total)}*\n';

    if (factura.observacionesCliente != null &&
        factura.observacionesCliente!.isNotEmpty) {
      mensaje += '\n📝 *Notas:* ${factura.observacionesCliente}\n';
    }

    return mensaje;
  }

  Future<void> _enviarPorWhatsApp(FacturaModel factura) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generando PDF y abriendo WhatsApp...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final pdfFile = await PdfService.generarPDF(factura);
      final xFile = XFile(pdfFile.path, mimeType: 'application/pdf');

      await Share.shareXFiles(
        [xFile],
        text: 'Factura de ${factura.nombreCliente}',
        subject: 'Factura #${factura.id}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al preparar PDF: $e')),
        );
      }
    }
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
                  _filtrarPorFecha(fechaSeleccionada!);
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
      _filtrarPorFecha(fechaSeleccionada!);
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
              _filtrarPorFecha(fechaSeleccionada!);
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
    final totalDia = facturasFiltradas.fold(0.0, (sum, factura) {
      return sum + factura.items.fold(0.0, (itemSum, item) => itemSum + item.subtotal);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturas'),
      ),
      body: Column(
        children: [
          // ==================== SELECTOR DE FECHA ====================
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar Fecha',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatearFecha(fechaSeleccionada ?? DateTime.now()),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.calendar_today, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _seleccionarFecha,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Cambiar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Resumen del día
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Facturas: ${facturasFiltradas.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Total: \$${_formatearPrecio(totalDia)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==================== LISTA DE FACTURAS ====================
          Expanded(
            child: facturasFiltradas.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay facturas para esta fecha',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: facturasFiltradas.length,
              itemBuilder: (context, index) {
                final factura = facturasFiltradas[index];
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
                          'Hora: ${factura.fecha.hour.toString().padLeft(2, '0')}:${factura.fecha.minute.toString().padLeft(2, '0')}',
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
                                  _enviarPorWhatsApp(factura);
                                },
                                child: const Text('Enviar por WhatsApp'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _descargarFactura(factura);
                                },
                                child: const Text('Descargar PDF'),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarMenuFlotante,
        child: const Icon(Icons.add),
      ),
    );
  }
}