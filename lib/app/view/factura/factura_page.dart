// ============= STATE NOTIFIER PARA FECHA =============
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../datasources/database_helper.dart';
import '../../model/factura_model.dart';
import '../../service/esc_pos_service.dart';
import '../../theme/app_colors.dart';
import 'crear_factura_clientes_page.dart';
import 'editar_factura_page.dart';
import 'resumen_productos__page.dart';
import '../../providers/factura_providers.dart';

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

// EDITAR FACTURA
  void _editarFactura(BuildContext context, WidgetRef ref, FacturaModel factura) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarFacturaPage(factura: factura),
      ),
    );


    if (resultado != null && resultado is FacturaModel) {
      ref.read(facturasStateProvider.notifier).actualizarFactura(resultado);
    }
  }

// ELIMINAR FACTURA
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
                // Primero eliminar del estado
                ref.read(facturasStateProvider.notifier).eliminarFactura(factura.id!);

                // Luego eliminar de Supabase
                await dbHelper.eliminarFactura(factura.id!);

                if (context.mounted) {
                  _mostrarSnackBar(context, 'Factura eliminada', isSuccess: true);
                }
              } catch (e) {
                // Si falla, recargar para restaurar el estado correcto
                ref.read(facturasStateProvider.notifier).cargarFacturas();

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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 24),
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

      if (opcion == 'pdf') {
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

        await EscPosService.descargarTicketPDF(factura);
        if (context.mounted) {
          Navigator.pop(context);
          _mostrarSnackBar(context, 'PDF generado correctamente', isSuccess: true);
        }
      } else if (opcion == 'bluetooth') {
        // Mostrar modal para seleccionar fecha
        if (context.mounted) {
          final fechaSeleccionada = await _mostrarSelectorFechaImpresion(context, factura);
          if (fechaSeleccionada == null) return;

          // Continuar con el proceso de impresión
          await _procesarImpresionBluetooth(context, factura, fechaSeleccionada);
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<DateTime?> _mostrarSelectorFechaImpresion(BuildContext context, FacturaModel factura) async {
    DateTime fechaSeleccionada = factura.fecha;

    return await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
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
                          'Imprimir Factura',
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

                  // Información de la factura
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                factura.nombreCliente,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${factura.items.length} productos',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selector de fecha
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha en la factura:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: fechaSeleccionada,
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
                              setState(() {
                                fechaSeleccionada = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _formatearFecha(fechaSeleccionada),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.edit, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Esta fecha aparecerá en la factura impresa',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botones de acción
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Cancelar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textSecondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(sheetContext, fechaSeleccionada),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Imprimir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _procesarImpresionBluetooth(BuildContext context, FacturaModel factura, DateTime fechaSeleccionada) async {
    try {
      // Mostrar diálogo de búsqueda
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
                Text('Buscando impresora...', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );

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
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.print, color: AppColors.primary, size: 20),
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

        // Crear factura con la fecha seleccionada
        final facturaConFechaModificada = FacturaModel(
          id: factura.id,
          clienteId: factura.clienteId,
          nombreCliente: factura.nombreCliente,
          direccionCliente: factura.direccionCliente,
          telefonoCliente: factura.telefonoCliente,
          negocioCliente: factura.negocioCliente,
          observacionesCliente: factura.observacionesCliente,
          rutaCliente: factura.rutaCliente,
          fecha: fechaSeleccionada,
          items: factura.items,
          estado: factura.estado,
          // total: factura.total,
        );

        await EscPosService.imprimirTicketBluetoothConDispositivo(facturaConFechaModificada, impresoraSeleccionada);

        if (context.mounted) {
          Navigator.pop(context);
          _mostrarSnackBar(context, 'Ticket enviado a impresora', isSuccess: true);
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
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
              title: const Text('Nueva Factura', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Crear factura para cliente', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () async {
                Navigator.pop(sheetContext);
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CrearFacturaMobile()),
                );
                if (resultado == true) {
                  await ref.read(facturasStateProvider.notifier).cargarFacturas();
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _mostrarMenuImprimirTodas(BuildContext context, WidgetRef ref, List<FacturaModel> facturas, DateTime fechaActual) {
    DateTime fechaSeleccionadaParaImprimir = fechaActual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
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
                          'Imprimir Facturas del Día',
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

                  // Información de facturas
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${facturas.length} ${facturas.length == 1 ? "factura" : "facturas"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Se imprimirán todas las facturas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selector de fecha para impresión
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha en las facturas:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: fechaSeleccionadaParaImprimir,
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
                              setState(() {
                                fechaSeleccionadaParaImprimir = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _formatearFecha(fechaSeleccionadaParaImprimir),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.edit, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Esta fecha aparecerá en todas las facturas impresas',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botones de acción
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Cancelar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textSecondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await _imprimirTodasLasFacturas(
                                context,
                                ref,
                                facturas,
                                fechaSeleccionadaParaImprimir,
                              );
                            },
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Imprimir Todas'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _imprimirTodasLasFacturas(
      BuildContext context,
      WidgetRef ref,
      List<FacturaModel> facturas,
      DateTime fechaParaImprimir,
      ) async {
    if (facturas.isEmpty) {
      _mostrarSnackBar(context, 'No hay facturas para imprimir', isError: true);
      return;
    }

    try {
      // Mostrar diálogo de carga
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
                Text('Buscando impresora...', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );

      // Escanear impresoras
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

      // Seleccionar impresora
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
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.print, color: AppColors.primary, size: 20),
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

        // Conectar a la impresora UNA SOLA VEZ
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
                    Text('Conectando...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        }

        final connectResult = await EscPosService.connectToDevice(impresoraSeleccionada);

        if (context.mounted) {
          Navigator.pop(context);
        }

        if (connectResult != BluetoothConnectionResult.success) {
          if (context.mounted) {
            _mostrarSnackBar(context, 'Error al conectar: ${connectResult.name}', isError: true);
          }
          return;
        }

        // Mostrar diálogo de progreso
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Imprimiendo 0/${facturas.length}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Imprimir cada factura
        for (int i = 0; i < facturas.length; i++) {
          // Crear una copia exacta de la factura con la fecha modificada
          final facturaParaImprimir = FacturaModel(
            id: facturas[i].id,
            clienteId: facturas[i].clienteId,
            nombreCliente: facturas[i].nombreCliente,
            direccionCliente: facturas[i].direccionCliente,
            telefonoCliente: facturas[i].telefonoCliente,
            negocioCliente: facturas[i].negocioCliente,
            observacionesCliente: facturas[i].observacionesCliente,
            rutaCliente: facturas[i].rutaCliente,
            fecha: fechaParaImprimir,
            items: facturas[i].items,
            estado: facturas[i].estado,
            // total: facturas[i].total,
          );

          // Generar bytes y enviar
          final bytes = await EscPosService.generarTicketEscPos(facturaParaImprimir);
          await EscPosService.sendPrintData(bytes);

          // Actualizar progreso
          if (context.mounted && i < facturas.length - 1) {
            Navigator.pop(context);
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Imprimiendo ${i + 2}/${facturas.length}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        // Pausa final para el último corte
        await Future.delayed(const Duration(seconds: 2));

        // Desconectar
        await EscPosService.disconnectPrinter();

        if (context.mounted) {
          Navigator.pop(context);
          _mostrarSnackBar(
            context,
            '${facturas.length} ${facturas.length == 1 ? "factura impresa" : "facturas impresas"}',
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      await EscPosService.disconnectPrinter();
      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarSnackBar(context, 'Error: $e', isError: true);
      }
    }
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
    final facturasAsync = ref.watch(facturasStateProvider);
    final facturasFiltradas = ref.watch(facturasFiltradasConBusquedaProvider); // CAMBIAR ESTA LÍNEA
    final fechaState = ref.watch(fechaProvider);
    final isSearching = ref.watch(isSearchingFacturasProvider);
    final searchQuery = ref.watch(searchQueryFacturasProvider);

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
        title: isSearching
            ? TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre, negocio o dirección...',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          onChanged: (value) {
            ref.read(searchQueryFacturasProvider.notifier).state = value;
          },
        )
            : _buildDateSelector(context, ref, fechaState),
        actions: [
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () {
                ref.read(isSearchingFacturasProvider.notifier).state = false;
                ref.read(searchQueryFacturasProvider.notifier).state = '';
              },
              tooltip: 'Cerrar búsqueda',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.primary),
              onPressed: () {
                ref.read(isSearchingFacturasProvider.notifier).state = true;
              },
              tooltip: 'Buscar facturas',
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined, color: AppColors.primary),
              onPressed: () {
                if (facturasFiltradas.isEmpty) {
                  _mostrarSnackBar(context, 'No hay facturas para imprimir', isError: true);
                } else {
                  _mostrarMenuImprimirTodas(context, ref, facturasFiltradas, fechaState.fechaSeleccionada);
                }
              },
              tooltip: 'Imprimir todas las facturas',
            ),
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
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CrearFacturaMobile()),
                );
              },
              tooltip: 'Nueva factura',
            ),
          ],
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
                      onPressed: () => ref.invalidate(facturasStateProvider),
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
                          child: Icon(
                            searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt_long,
                            size: 64,
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          searchQuery.isNotEmpty ? 'Sin resultados' : 'Sin facturas',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No se encontraron facturas con "$searchQuery"'
                              : 'No hay facturas para esta fecha',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (searchQuery.isEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CrearFacturaMobile()),
                              );
                            },
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
                                        factura.negocioCliente ?? 'Sin negocio',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        factura.nombreCliente,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        factura.direccionCliente,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
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