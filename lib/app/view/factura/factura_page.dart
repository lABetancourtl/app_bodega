import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/view/factura/crear_factura_clientes_page.dart';
import 'package:app_bodega/app/view/factura/crear_factura_limpia_page.dart';
import 'package:app_bodega/app/view/factura/editar_factura_page.dart';
import 'package:app_bodega/app/view/factura/resumen_productos__page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/esc_pos_service.dart';
import 'package:app_bodega/app/theme/app_colors.dart';



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
    final dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dias[fecha.weekday % 7]}, ${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  void _mostrarSnackBar(BuildContext context, String mensaje, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : (isError ? Icons.error : Icons.info),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.accent : (isError ? AppColors.error : AppColors.primary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
      ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(fechaProvider.notifier).setFecha(picked);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Factura'),
          ],
        ),
        content: Text('¿Eliminar la factura de ${factura.nombreCliente}?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await dbHelper.eliminarFactura(factura.id!);
                ref.invalidate(facturasProvider);
                if (context.mounted) {
                  _mostrarSnackBar(context, 'Factura eliminada', isSuccess: true);
                }
              } catch (e) {
                if (context.mounted) {
                  _mostrarSnackBar(context, 'Error: $e', isError: true);
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _descargarFacturaPOS(BuildContext context, FacturaModel factura) async {
    try {
      final opcion = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Seleccionar formato',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 24),
                  ),
                  title: const Text('Descargar PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Guardar como PDF (80mm)', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => Navigator.pop(context, 'pdf'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bluetooth, color: AppColors.primary, size: 24),
                  ),
                  title: const Text('Imprimir Bluetooth', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enviar a impresora térmica', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => Navigator.pop(context, 'bluetooth'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );

      if (opcion == null) return;

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Procesando...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }

      if (opcion == 'pdf') {
        await EscPosService.descargarTicketPDF(factura);
        if (context.mounted) {
          Navigator.pop(context);
          _mostrarSnackBar(context, 'PDF generado correctamente', isSuccess: true);
        }
      } else if (opcion == 'bluetooth') {
        List<BluetoothDevice> impresoras = await EscPosService.escanearImpresorasBluetooth();

        if (context.mounted) {
          Navigator.pop(context);
        }

        if (impresoras.isEmpty) {
          if (context.mounted) {
            _mostrarSnackBar(context, 'No se encontraron impresoras Bluetooth', isError: true);
          }
          return;
        }

        if (context.mounted) {
          final impresoraSeleccionada = await showDialog<BluetoothDevice>(
            context: context,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.print, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('Seleccionar Impresora'),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: impresoras.length,
                    itemBuilder: (context, index) {
                      final impresora = impresoras[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.print, color: AppColors.accent, size: 20),
                        ),
                        title: Text(
                          impresora.platformName.isNotEmpty ? impresora.platformName : 'Impresora ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(impresora.remoteId.toString(), style: const TextStyle(fontSize: 12)),
                        onTap: () => Navigator.pop(context, impresora),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              );
            },
          );

          if (impresoraSeleccionada == null) return;

          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }

          await EscPosService.imprimirTicketBluetoothConDispositivo(factura, impresoraSeleccionada);

          if (context.mounted) {
            Navigator.pop(context);
            _mostrarSnackBar(context, 'Ticket enviado a impresora', isSuccess: true);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  void _mostrarOpcionesFactura(BuildContext context, WidgetRef ref, FacturaModel factura) {
    final total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factura.nombreCliente,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${_formatearPrecio(total)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
              ),
              title: const Text('Imprimir / Descargar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _descargarFacturaPOS(context, factura);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.accent, size: 20),
              ),
              title: const Text('Editar factura'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editarFactura(context, ref, factura);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              ),
              title: const Text('Eliminar factura', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _eliminarFactura(context, ref, factura);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _mostrarMenuFlotante(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Nueva Factura',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_cart, color: AppColors.primary, size: 24),
              ),
              title: const Text('Factura a Clientes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Cliente registrado en el sistema', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CrearFacturaPage()),
                );
                ref.invalidate(facturasProvider);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 24),
              ),
              title: const Text('Factura Limpia', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Cliente ocasional sin registro', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CrearFacturaLimpiaPage()),
                );
                ref.invalidate(facturasProvider);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, FechaState fechaState) {
    return GestureDetector(
      onTap: () => _seleccionarFecha(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.calendar_today, color: Colors.white, size: 14),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                _formatearFecha(fechaState.fechaSeleccionada),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: _buildDateSelector(context, ref, fechaState),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
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
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _mostrarMenuFlotante(context, ref),
            tooltip: 'Nueva factura',
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen del día
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Facturas del día',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${facturasFiltradas.length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.border,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total vendido',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatearPrecio(totalDia)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de facturas
          Expanded(
            child: facturasAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Cargando facturas...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error: $err', style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(facturasProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (facturas) {
                if (facturasFiltradas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.receipt_long, size: 64, color: AppColors.primary.withOpacity(0.3)),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Sin facturas',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No hay facturas para esta fecha',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _mostrarMenuFlotante(context, ref),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Nueva Factura'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: facturasFiltradas.length,
                  itemBuilder: (context, index) {
                    final factura = facturasFiltradas[index];
                    final total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _mostrarOpcionesFactura(context, ref, factura),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        factura.nombreCliente,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${factura.fecha.hour.toString().padLeft(2, '0')}:${factura.fecha.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.inventory_2_outlined, size: 12, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${factura.items.length} items',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '\$${_formatearPrecio(total)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }
}