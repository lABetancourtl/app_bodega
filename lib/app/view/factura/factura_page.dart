import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/service/cache_manager.dart';
import 'package:app_bodega/app/service/pdf_service.dart';
import 'package:app_bodega/app/view/factura/crear_factura_page.dart';
import 'package:app_bodega/app/view/factura/editar_factura_page.dart';
import 'package:app_bodega/app/view/factura/resumen_productos__page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

// ============= STATE NOTIFIER PARA FECHA =============
class FechaState {
  final DateTime fechaSeleccionada;

  FechaState({required this.fechaSeleccionada});

  FechaState copyWith({DateTime? fechaSeleccionada}) {
    return FechaState(
      fechaSeleccionada: fechaSeleccionada ?? this.fechaSeleccionada,
    );
  }
}

class FechaNotifier extends StateNotifier<FechaState> {
  FechaNotifier() : super(FechaState(fechaSeleccionada: DateTime.now()));

  void setFecha(DateTime fecha) {
    state = state.copyWith(fechaSeleccionada: fecha);
  }
}

final fechaProvider = StateNotifierProvider<FechaNotifier, FechaState>((ref) {
  return FechaNotifier();
});

// ============= PROVIDERS =============
final facturasProvider = FutureProvider<List<FacturaModel>>((ref) async {
  final dbHelper = DatabaseHelper();
  return await dbHelper.obtenerFacturas();
});

final facturasFiltradasProvider = Provider<List<FacturaModel>>((ref) {
  final facturasAsync = ref.watch(facturasProvider);
  final fechaState = ref.watch(fechaProvider);

  return facturasAsync.whenData((facturas) {
    final fecha = fechaState.fechaSeleccionada;
    return facturas.where((factura) {
      return factura.fecha.year == fecha.year &&
          factura.fecha.month == fecha.month &&
          factura.fecha.day == fecha.day;
    }).toList();
  }).maybeWhen(
    data: (data) => data,
    orElse: () => [],
  );
});

// ============= PÁGINA =============
class FacturaPage extends ConsumerWidget {
  const FacturaPage({super.key});

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

  void _seleccionarFecha(BuildContext context, WidgetRef ref) async {
    final fechaState = ref.read(fechaProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaState.fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      ref.read(fechaProvider.notifier).setFecha(picked);
    }
  }

  Future<void> _enviarPorWhatsApp(BuildContext context, FacturaModel factura) async {
    try {
      if (context.mounted) {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al preparar PDF: $e')),
        );
      }
    }
  }

  void _editarFactura(BuildContext context, WidgetRef ref, FacturaModel factura) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarFacturaPage(factura: factura),
      ),
    );
    ref.invalidate(facturasProvider);
  }

  void _eliminarFactura(BuildContext context, WidgetRef ref, FacturaModel factura) {
    final dbHelper = DatabaseHelper();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Factura'),
        content: Text('¿Estás seguro de que deseas eliminar la factura de ${factura.nombreCliente}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await dbHelper.eliminarFactura(factura.id!);
                ref.invalidate(facturasProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Factura eliminada')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _descargarFactura(BuildContext context, FacturaModel factura) async {
    try {
      await PdfService.generarYDescargarPDF(factura);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }

  void _mostrarMenuFlotante(BuildContext context, WidgetRef ref) {
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
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CrearFacturaPage(),
                  ),
                );
                ref.invalidate(facturasProvider);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final facturasAsync = ref.watch(facturasProvider);
    final facturasFiltradas = ref.watch(facturasFiltradasProvider);
    final fechaState = ref.watch(fechaProvider);

    final totalDia = facturasFiltradas.fold(0.0, (sum, factura) {
      return sum + factura.items.fold(0.0, (itemSum, item) => itemSum + item.subtotal);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Facturas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResumenProductosDiaPage(
                    facturas: facturasFiltradas,
                    fecha: fechaState.fechaSeleccionada,
                  ),
                ),
              );
            },
            tooltip: 'Ver resumen de productos',
          ),
        ],
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
                              _formatearFecha(fechaState.fechaSeleccionada),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.calendar_today, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _seleccionarFecha(context, ref),
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
            child: facturasAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando facturas...'),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $err'),
                  ],
                ),
              ),
              data: (facturas) {
                if (facturasFiltradas.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay facturas para esta fecha',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
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
                                      _editarFactura(context, ref, factura);
                                    },
                                    child: const Text('Editar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _enviarPorWhatsApp(context, factura);
                                    },
                                    child: const Text('Enviar por WhatsApp'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _descargarFactura(context, factura);
                                    },
                                    child: const Text('Descargar PDF'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _eliminarFactura(context, ref, factura);
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarMenuFlotante(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}