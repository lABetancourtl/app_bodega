import 'dart:io';
import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_bodega/app/theme/app_colors.dart';

// Provider para el descuento global
final descuentoGlobalProvider = StateProvider<DescuentoModel?>((ref) => null);

class CarritoProductosPage extends ConsumerWidget {
  const CarritoProductosPage({super.key});

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

  Future<void> _editarProducto(
      BuildContext context,
      WidgetRef ref,
      int index,
      ItemFacturaModel itemActual,
      ) async {
    final dbHelper = DatabaseHelper();
    final producto = await dbHelper.obtenerProductoPorId(itemActual.productoId);

    if (producto == null) {
      if (context.mounted) {
        _mostrarSnackBar(context, 'No se encontró el producto', isError: true);
      }
      return;
    }

    if (!context.mounted) return;

    final itemEditado = await _mostrarDialogoEdicion(context, producto, itemActual);

    if (itemEditado != null) {
      final carritoProvider = ref.read(carritoTemporalProvider.notifier);
      final carritoActual = ref.read(carritoTemporalProvider);
      final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);
      nuevoCarrito[index] = itemEditado;
      carritoProvider.state = nuevoCarrito;

      if (context.mounted) {
        _mostrarSnackBar(context, 'Producto actualizado', isSuccess: true);
      }
    }
  }

  Future<ItemFacturaModel?> _mostrarDialogoEdicion(
      BuildContext context,
      ProductoModel producto,
      ItemFacturaModel itemActual,
      ) async {
    final TextEditingController cantidadTotalController =
    TextEditingController(text: itemActual.cantidadTotal.toString());
    final Map<String, TextEditingController> controllersPorSabor = {};
    final Map<String, int> cantidadPorSabor = Map.from(itemActual.cantidadPorSabor);

    for (var sabor in producto.sabores) {
      final cantidad = cantidadPorSabor[sabor] ?? 0;
      controllersPorSabor[sabor] = TextEditingController(text: cantidad.toString());
    }

    int calcularTotal() {
      return cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);
    }

    return await showModalBottomSheet<ItemFacturaModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                producto.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '\$${_formatearPrecio(producto.precio)} c/u',
                                style: const TextStyle(fontSize: 14, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (producto.sabores.length == 1) ...[
                          TextField(
                            controller: cantidadTotalController,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Cantidad',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              prefixIcon: const Icon(Icons.inventory, color: AppColors.primary),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (producto.sabores.length > 1) ...[
                          const Text(
                            'Distribuir por sabor:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 16),
                          ...producto.sabores.map((sabor) {
                            final controller = controllersPorSabor[sabor]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(sabor, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                      ),
                                      onTap: () {
                                        if (controller.text == '0') controller.clear();
                                      },
                                      onChanged: (value) {
                                        cantidadPorSabor[sabor] = int.tryParse(value) ?? 0;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],
                        // Total box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.sabores.length == 1
                                        ? '${int.tryParse(cantidadTotalController.text) ?? 0} unidades'
                                        : '${calcularTotal()} unidades',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                ],
                              ),
                              Text(
                                producto.sabores.length == 1
                                    ? '\$${_formatearPrecio((int.tryParse(cantidadTotalController.text) ?? 0) * producto.precio)}'
                                    : '\$${_formatearPrecio(calcularTotal() * producto.precio)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              int cantidadTotal;
                              if (producto.sabores.length == 1) {
                                cantidadTotal = int.tryParse(cantidadTotalController.text) ?? 0;
                                if (cantidadTotal <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('La cantidad debe ser mayor a 0')),
                                  );
                                  return;
                                }
                              } else {
                                cantidadTotal = calcularTotal();
                                if (cantidadTotal <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Debes agregar al menos una unidad')),
                                  );
                                  return;
                                }
                              }
                              final itemActualizado = ItemFacturaModel(
                                productoId: producto.id!,
                                nombreProducto: producto.nombre,
                                precioUnitario: producto.precio,
                                cantidadTotal: cantidadTotal,
                                cantidadPorSabor: producto.sabores.length > 1 ? cantidadPorSabor : {producto.sabores[0]: cantidadTotal},
                                tieneSabores: producto.sabores.length > 1,
                                descuento: itemActual.descuento, // Mantener el descuento
                              );
                              Navigator.pop(context, itemActualizado);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _eliminarProducto(BuildContext context, WidgetRef ref, int index, String nombreProducto) {
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
            const Text('Eliminar Producto'),
          ],
        ),
        content: Text('¿Eliminar "$nombreProducto" del carrito?'),
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
            onPressed: () {
              final carritoProvider = ref.read(carritoTemporalProvider.notifier);
              final carritoActual = ref.read(carritoTemporalProvider);
              final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);
              nuevoCarrito.removeAt(index);
              carritoProvider.state = nuevoCarrito;
              Navigator.pop(dialogContext);
              _mostrarSnackBar(context, 'Producto eliminado', isSuccess: true);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============= APLICAR DESCUENTO A UN PRODUCTO =============
  Future<void> _aplicarDescuentoProducto(
      BuildContext context,
      WidgetRef ref,
      int index,
      ItemFacturaModel item,
      ) async {
    final descuento = await showDialog<DescuentoModel>(
      context: context,
      builder: (context) => AplicarDescuentoItemDialog(
        nombreProducto: item.nombreProducto,
        precioUnitario: item.precioUnitario,
        cantidad: item.cantidadTotal,
        descuentoActual: item.descuento,
      ),
    );

    if (descuento != null) {
      final carritoProvider = ref.read(carritoTemporalProvider.notifier);
      final carritoActual = ref.read(carritoTemporalProvider);
      final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);

      // Si el descuento es "ninguno", eliminarlo
      if (descuento.tipo == TipoDescuento.ninguno) {
        nuevoCarrito[index] = item.copyWith(eliminarDescuento: true);
        if (context.mounted) {
          _mostrarSnackBar(context, 'Descuento removido', isSuccess: true);
        }
      } else {
        nuevoCarrito[index] = item.copyWith(descuento: descuento);
        if (context.mounted) {
          _mostrarSnackBar(context, 'Descuento aplicado', isSuccess: true);
        }
      }

      carritoProvider.state = nuevoCarrito;
    }
  }

  // ============= APLICAR DESCUENTO GLOBAL =============
  Future<void> _aplicarDescuentoGlobal(BuildContext context, WidgetRef ref, double subtotal) async {
    final descuentoActual = ref.read(descuentoGlobalProvider);

    final descuento = await showDialog<DescuentoModel>(
      context: context,
      builder: (context) => AplicarDescuentoGlobalDialog(
        subtotal: subtotal,
        descuentoActual: descuentoActual,
      ),
    );

    if (descuento != null) {
      if (descuento.tipo == TipoDescuento.ninguno) {
        ref.read(descuentoGlobalProvider.notifier).state = null;
        if (context.mounted) {
          _mostrarSnackBar(context, 'Descuento global removido', isSuccess: true);
        }
      } else {
        ref.read(descuentoGlobalProvider.notifier).state = descuento;
        if (context.mounted) {
          _mostrarSnackBar(context, 'Descuento global aplicado', isSuccess: true);
        }
      }
    }
  }

  void _finalizarSeleccion(BuildContext context, WidgetRef ref) {
    final carrito = ref.read(carritoTemporalProvider);

    if (carrito.isEmpty) {
      _mostrarSnackBar(context, 'El carrito está vacío', isError: true);
      return;
    }

    // Obtener el descuento global antes de limpiar
    final descuentoGlobal = ref.read(descuentoGlobalProvider);

    // Pasar el carrito Y el descuento global como un mapa
    Navigator.pop(context, {
      'items': carrito,
      'descuentoGlobal': descuentoGlobal,
    });

    // Limpiar el descuento global después de pasarlo
    ref.read(descuentoGlobalProvider.notifier).state = null;
  }

  void _vaciarCarrito(BuildContext context, WidgetRef ref) {
    final carrito = ref.read(carritoTemporalProvider);

    if (carrito.isEmpty) {
      _mostrarSnackBar(context, 'El carrito ya está vacío', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove_shopping_cart, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Vaciar Carrito'),
          ],
        ),
        content: Text('¿Eliminar todos los productos? (${carrito.length} productos)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ref.read(carritoTemporalProvider.notifier).state = [];
              ref.read(descuentoGlobalProvider.notifier).state = null;
              Navigator.pop(dialogContext);
              _mostrarSnackBar(context, 'Carrito vaciado', isSuccess: true);
            },
            child: const Text('Vaciar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _construirImagenProducto(String? imagenPath) {
    if (imagenPath != null && imagenPath.isNotEmpty && imagenPath.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imagenPath,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _imagenPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) => _imagenPorDefecto(),
        ),
      );
    }
    return _imagenPorDefecto();
  }

  Widget _imagenPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      ),
    );
  }

  Widget _imagenPorDefecto() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.1), AppColors.accent.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.primary),
    );
  }

  Future<String?> _obtenerImagenProducto(String productoId) async {
    try {
      final dbHelper = DatabaseHelper();
      final producto = await dbHelper.obtenerProductoPorId(productoId);
      return producto?.imagenPath;
    } catch (e) {
      return null;
    }
  }

  double _calcularTotalConDescuentos(List<ItemFacturaModel> carrito, DescuentoModel? descuentoGlobal) {
    // Total con descuentos de items
    double subtotal = carrito.fold(0.0, (sum, item) => sum + item.subtotal);

    // Aplicar descuento global si existe
    if (descuentoGlobal != null && descuentoGlobal.tieneDescuento) {
      subtotal = descuentoGlobal.aplicarDescuento(subtotal);
    }

    return subtotal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoTemporalProvider);
    final descuentoGlobal = ref.watch(descuentoGlobalProvider);

    double subtotalSinDescuentos = carrito.fold(0, (sum, item) => sum + item.subtotalSinDescuento);
    double subtotalConDescuentosItems = carrito.fold(0, (sum, item) => sum + item.subtotal);
    double total = _calcularTotalConDescuentos(carrito, descuentoGlobal);
    double totalDescuentos = subtotalSinDescuentos - total;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Carrito',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (carrito.isNotEmpty)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove_shopping_cart, color: AppColors.warning, size: 20),
              ),
              onPressed: () => _vaciarCarrito(context, ref),
              tooltip: 'Vaciar carrito',
            ),
        ],
      ),
      body: Column(
        children: [
          // Resumen
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_cart, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Productos en carrito', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            '${carrito.length} ${carrito.length == 1 ? "producto" : "productos"}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '\$${_formatearPrecio(total)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),

                // Mostrar descuentos si existen
                if (totalDescuentos > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ahorras:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '\$${_formatearPrecio(totalDescuentos)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                        if (descuentoGlobal != null && descuentoGlobal.tieneDescuento)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Desc. Global ${descuentoGlobal.toString()}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botón de descuento global
          // if (carrito.isNotEmpty)
          //   Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     child: SizedBox(
          //       width: double.infinity,
          //       child: OutlinedButton.icon(
          //         onPressed: () => _aplicarDescuentoGlobal(context, ref, subtotalConDescuentosItems),
          //         icon: Icon(
          //           descuentoGlobal != null && descuentoGlobal.tieneDescuento
          //               ? Icons.edit
          //               : Icons.local_offer,
          //           size: 18,
          //         ),
          //         label: Text(
          //           descuentoGlobal != null && descuentoGlobal.tieneDescuento
          //               ? 'Editar Descuento Global (${descuentoGlobal.toString()})'
          //               : 'Aplicar Descuento Global',
          //         ),
          //         style: OutlinedButton.styleFrom(
          //           foregroundColor: AppColors.accent,
          //           side: BorderSide(
          //             color: descuentoGlobal != null && descuentoGlobal.tieneDescuento
          //                 ? AppColors.accent
          //                 : AppColors.border,
          //             width: descuentoGlobal != null && descuentoGlobal.tieneDescuento ? 2 : 1,
          //           ),
          //           padding: const EdgeInsets.symmetric(vertical: 12),
          //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          //         ),
          //       ),
          //     ),
          //   ),

          const SizedBox(height: 8),

          // Lista de productos
          Expanded(
            child: carrito.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.primary.withOpacity(0.3)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Carrito vacío', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Agrega productos para continuar', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: carrito.length,
              itemBuilder: (context, index) {
                final item = carrito[index];
                final tieneDescuento = item.descuento != null && item.descuento!.tieneDescuento;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tieneDescuento ? AppColors.success.withOpacity(0.5) : AppColors.border,
                      width: tieneDescuento ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _editarProducto(context, ref, index, item),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              FutureBuilder<String?>(
                                future: _obtenerImagenProducto(item.productoId),
                                builder: (context, snapshot) {
                                  return _construirImagenProducto(snapshot.data);
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nombreProducto,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (item.tieneSabores)
                                      Text(
                                        item.cantidadPorSabor.entries.map((e) => '${e.key} (${e.value})').join(', '),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Row(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${item.cantidadTotal} uds',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (tieneDescuento) ...[
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.textSecondary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '\$${_formatearPrecio(item.subtotalSinDescuento)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '\$${_formatearPrecio(item.subtotal)}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: tieneDescuento
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        tieneDescuento ? Icons.discount : Icons.local_offer_outlined,
                                        color: tieneDescuento ? AppColors.success : AppColors.primary,
                                        size: 18,
                                      ),
                                    ),
                                    onPressed: () => _aplicarDescuentoProducto(context, ref, index, item),
                                    tooltip: 'Descuento',
                                  ),
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                    ),
                                    onPressed: () => _eliminarProducto(context, ref, index, item.nombreProducto),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Badge de descuento si existe
                          if (tieneDescuento)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.success.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_offer, color: AppColors.success, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Descuento ${item.descuento!.toString()}${item.descuento!.motivo != null ? " - ${item.descuento!.motivo}" : ""}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Ahorras \$${_formatearPrecio(item.montoDescuento)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: carrito.isNotEmpty
          ? Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () => _finalizarSeleccion(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Confirmar (\$${_formatearPrecio(total)})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }
}

// ============= WIDGET PARA APLICAR DESCUENTO A UN ITEM =============
class AplicarDescuentoItemDialog extends StatefulWidget {
  final String nombreProducto;
  final double precioUnitario;
  final int cantidad;
  final DescuentoModel? descuentoActual;

  const AplicarDescuentoItemDialog({
    super.key,
    required this.nombreProducto,
    required this.precioUnitario,
    required this.cantidad,
    this.descuentoActual,
  });

  @override
  State<AplicarDescuentoItemDialog> createState() => _AplicarDescuentoItemDialogState();
}

class _AplicarDescuentoItemDialogState extends State<AplicarDescuentoItemDialog> {
  late TipoDescuento _tipoSeleccionado;
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.descuentoActual?.tipo ?? TipoDescuento.porcentaje;
    _valorController.text = widget.descuentoActual?.valor.toString() ?? '';
    _motivoController.text = widget.descuentoActual?.motivo ?? '';
  }

  @override
  void dispose() {
    _valorController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  double _calcularPrecioConDescuento() {
    final valor = double.tryParse(_valorController.text) ?? 0;
    if (_tipoSeleccionado == TipoDescuento.porcentaje) {
      return widget.precioUnitario * (1 - valor / 100);
    } else if (_tipoSeleccionado == TipoDescuento.monto) {
      return widget.precioUnitario - valor;
    }
    return widget.precioUnitario;
  }

  double _calcularDescuentoTotal() {
    return (widget.precioUnitario - _calcularPrecioConDescuento()) * widget.cantidad;
  }

  @override
  Widget build(BuildContext context) {
    final precioConDescuento = _calcularPrecioConDescuento();
    final descuentoTotal = _calcularDescuentoTotal();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.discount, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Aplicar Descuento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.nombreProducto,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info del producto
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Precio unitario:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('\$${_formatearPrecio(widget.precioUnitario)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Cantidad:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('${widget.cantidad} uds', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tipo de descuento
                    const Text('Tipo de descuento:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTipoButton(
                            'Porcentaje',
                            Icons.percent,
                            TipoDescuento.porcentaje,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTipoButton(
                            'Monto Fijo',
                            Icons.attach_money,
                            TipoDescuento.monto,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Campo de valor
                    TextField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: _tipoSeleccionado == TipoDescuento.porcentaje
                            ? 'Porcentaje de descuento'
                            : 'Monto de descuento',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        prefixIcon: Icon(
                          _tipoSeleccionado == TipoDescuento.porcentaje
                              ? Icons.percent
                              : Icons.attach_money,
                          color: AppColors.primary,
                        ),
                        suffixText: _tipoSeleccionado == TipoDescuento.porcentaje ? '%' : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 16),

                    // Motivo (opcional)
                    TextField(
                      controller: _motivoController,
                      decoration: InputDecoration(
                        labelText: 'Motivo (opcional)',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        hintText: 'Ej: Cliente frecuente, Promoción',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.note, color: AppColors.primary),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Resumen del descuento
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Precio unitario original:', style: TextStyle(fontSize: 13)),
                              Text(
                                '\$${_formatearPrecio(widget.precioUnitario)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Precio con descuento:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                '\$${_formatearPrecio(precioConDescuento)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ahorras en total:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(
                                '\$${_formatearPrecio(descuentoTotal)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botones
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final valor = double.tryParse(_valorController.text) ?? 0;
                          if (valor <= 0) {
                            Navigator.pop(context, DescuentoModel.sinDescuento());
                            return;
                          }

                          final descuento = DescuentoModel(
                            tipo: _tipoSeleccionado,
                            valor: valor,
                            motivo: _motivoController.text.isEmpty ? null : _motivoController.text,
                          );
                          Navigator.pop(context, descuento);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoButton(String label, IconData icon, TipoDescuento tipo) {
    final isSelected = _tipoSeleccionado == tipo;
    return InkWell(
      onTap: () => setState(() => _tipoSeleccionado = tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= WIDGET PARA APLICAR DESCUENTO GLOBAL A LA FACTURA =============
class AplicarDescuentoGlobalDialog extends StatefulWidget {
  final double subtotal;
  final DescuentoModel? descuentoActual;

  const AplicarDescuentoGlobalDialog({
    super.key,
    required this.subtotal,
    this.descuentoActual,
  });

  @override
  State<AplicarDescuentoGlobalDialog> createState() => _AplicarDescuentoGlobalDialogState();
}

class _AplicarDescuentoGlobalDialogState extends State<AplicarDescuentoGlobalDialog> {
  late TipoDescuento _tipoSeleccionado;
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.descuentoActual?.tipo ?? TipoDescuento.porcentaje;
    _valorController.text = widget.descuentoActual?.valor.toString() ?? '';
    _motivoController.text = widget.descuentoActual?.motivo ?? '';
  }

  @override
  void dispose() {
    _valorController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  double _calcularDescuento() {
    final valor = double.tryParse(_valorController.text) ?? 0;
    if (_tipoSeleccionado == TipoDescuento.porcentaje) {
      return widget.subtotal * (valor / 100);
    } else if (_tipoSeleccionado == TipoDescuento.monto) {
      return valor;
    }
    return 0;
  }

  double _calcularTotalFinal() {
    return widget.subtotal - _calcularDescuento();
  }

  @override
  Widget build(BuildContext context) {
    final descuento = _calcularDescuento();
    final totalFinal = _calcularTotalFinal();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withOpacity(0.2),
                      AppColors.primary.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descuento Global',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Aplica a toda la factura',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtotal actual
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            '\$${_formatearPrecio(widget.subtotal)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tipo de descuento
                    const Text('Tipo de descuento:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTipoButton('Porcentaje', Icons.percent, TipoDescuento.porcentaje),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTipoButton('Monto Fijo', Icons.attach_money, TipoDescuento.monto),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Campo de valor
                    TextField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: _tipoSeleccionado == TipoDescuento.porcentaje
                            ? 'Porcentaje de descuento'
                            : 'Monto de descuento',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        ),
                        prefixIcon: Icon(
                          _tipoSeleccionado == TipoDescuento.porcentaje ? Icons.percent : Icons.attach_money,
                          color: AppColors.accent,
                        ),
                        suffixText: _tipoSeleccionado == TipoDescuento.porcentaje ? '%' : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 16),

                    // Motivo
                    TextField(
                      controller: _motivoController,
                      decoration: InputDecoration(
                        labelText: 'Motivo (opcional)',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        hintText: 'Ej: Compra mayorista',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.note, color: AppColors.accent),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Resumen
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withOpacity(0.1),
                            AppColors.accent.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(fontSize: 13)),
                              Text('\$${_formatearPrecio(widget.subtotal)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Descuento:', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                              Text(
                                '- \$${_formatearPrecio(descuento)}',
                                style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL FINAL:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(
                                '\$${_formatearPrecio(totalFinal)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botones
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final valor = double.tryParse(_valorController.text) ?? 0;
                          if (valor <= 0) {
                            Navigator.pop(context, DescuentoModel.sinDescuento());
                            return;
                          }

                          final descuento = DescuentoModel(
                            tipo: _tipoSeleccionado,
                            valor: valor,
                            motivo: _motivoController.text.isEmpty ? null : _motivoController.text,
                          );
                          Navigator.pop(context, descuento);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoButton(String label, IconData icon, TipoDescuento tipo) {
    final isSelected = _tipoSeleccionado == tipo;
    return InkWell(
      onTap: () => setState(() => _tipoSeleccionado = tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}