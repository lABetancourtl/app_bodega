import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';
import 'package:app_bodega/app/theme/app_colors.dart';


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

  void _mostrarSnackBar(String mensaje, {bool isSuccess = false, bool isError = false}) {
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
    // if (clienteSeleccionado == null) {
    //   _mostrarSnackBar('Por favor selecciona un cliente primero', isError: true);
    //   return;
    // }

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AgregarProductoFacturaPage(),
      ),
    );

    if (resultado != null) {
      setState(() {
        if (resultado is List<ItemFacturaModel>) {
          for (var nuevoItem in resultado) {
            final indexExistente = items.indexWhere(
                  (item) => item.productoId == nuevoItem.productoId,
            );

            if (indexExistente != -1) {
              items[indexExistente] = nuevoItem;
            } else {
              items.add(nuevoItem);
            }
          }

          _mostrarSnackBar(
            '${resultado.length} ${resultado.length == 1 ? "producto procesado" : "productos procesados"}',
            isSuccess: true,
          );
        } else if (resultado is ItemFacturaModel) {
          final indexExistente = items.indexWhere(
                (item) => item.productoId == resultado.productoId,
          );

          if (indexExistente != -1) {
            items[indexExistente] = resultado;
          } else {
            items.add(resultado);
          }

          _mostrarSnackBar('Producto agregado', isSuccess: true);
        }
      });
    }
  }

  void _eliminarProducto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        content: Text('¿Eliminar "${items[index].nombreProducto}" de la factura?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                items.removeAt(index);
              });
              Navigator.pop(context);
              _mostrarSnackBar('Producto eliminado', isSuccess: true);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _guardarFactura() async {
    if (clienteSeleccionado == null) {
      _mostrarSnackBar('Por favor selecciona un cliente', isError: true);
      return;
    }

    if (items.isEmpty) {
      _mostrarSnackBar('Por favor agrega al menos un producto', isError: true);
      return;
    }

    final factura = FacturaModel(
      clienteId: clienteSeleccionado!.id!,
      nombreCliente: clienteSeleccionado!.nombre,
      direccionCliente: clienteSeleccionado!.direccion,
      telefonoCliente: clienteSeleccionado!.telefono,
      negocioCliente: clienteSeleccionado!.nombreNegocio,
      observacionesCliente: clienteSeleccionado!.observaciones,
      fecha: DateTime.now(),
      items: items,
      estado: 'pendiente',
    );

    try {
      await _dbHelper.insertarFactura(factura);

      if (mounted) {
        _mostrarSnackBar('Factura guardada para ${clienteSeleccionado!.nombre}', isSuccess: true);
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      _mostrarSnackBar('Error al guardar: $e', isError: true);
    }
  }

  void _editarProducto(int index) async {
    final itemActual = items[index];
    final producto = await _dbHelper.obtenerProductoPorId(itemActual.productoId);

    if (producto == null) {
      if (mounted) {
        _mostrarSnackBar('No se encontró el producto', isError: true);
      }
      return;
    }

    if (!mounted) return;

    final itemEditado = await _mostrarDialogoEdicion(producto, itemActual);

    if (itemEditado != null) {
      setState(() {
        items[index] = itemEditado;
      });
      _mostrarSnackBar('Producto actualizado', isSuccess: true);
    }
  }

  Future<ItemFacturaModel?> _mostrarDialogoEdicion(
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, left: 0, right: 0),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ).wrapCenter(),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
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
                                    child: Text(
                                      sabor,
                                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                      ),
                                      onTap: () {
                                        if (controller.text == '0') {
                                          controller.clear();
                                        }
                                      },
                                      onChanged: (value) {
                                        final cantidad = int.tryParse(value) ?? 0;
                                        cantidadPorSabor[sabor] = cantidad;
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
                        // Total
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
                                  const Text(
                                    'TOTAL:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Text(
                                producto.sabores.length == 1
                                    ? '\$${_formatearPrecio((int.tryParse(cantidadTotalController.text) ?? 0) * producto.precio)}'
                                    : '\$${_formatearPrecio(calcularTotal() * producto.precio)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: AppColors.accent,
                                ),
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
                                if (cantidadTotalController.text.isEmpty) {
                                  _mostrarSnackBar('Por favor ingresa la cantidad', isError: true);
                                  return;
                                }
                                cantidadTotal = int.parse(cantidadTotalController.text);
                                if (cantidadTotal <= 0) {
                                  _mostrarSnackBar('La cantidad debe ser mayor a 0', isError: true);
                                  return;
                                }
                              } else {
                                cantidadTotal = calcularTotal();
                                if (cantidadTotal <= 0) {
                                  _mostrarSnackBar('Debes agregar al menos una unidad', isError: true);
                                  return;
                                }
                              }
                              final itemActualizado = ItemFacturaModel(
                                productoId: producto.id!,
                                nombreProducto: producto.nombre,
                                precioUnitario: producto.precio,
                                cantidadTotal: cantidadTotal,
                                cantidadPorSabor: producto.sabores.length > 1
                                    ? cantidadPorSabor
                                    : {producto.sabores[0]: cantidadTotal},
                                tieneSabores: producto.sabores.length > 1,
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

  @override
  Widget build(BuildContext context) {
    double total = items.fold(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Nueva Factura',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _guardarFactura,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Seleccionar Cliente
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _seleccionarCliente,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                    color: clienteSeleccionado == null ? AppColors.primary : AppColors.accent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: clienteSeleccionado == null
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        clienteSeleccionado == null ? Icons.person_add : Icons.check_circle,
                        color: clienteSeleccionado == null ? AppColors.primary : AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clienteSeleccionado == null ? 'Seleccionar Cliente' : clienteSeleccionado!.nombreNegocio ?? clienteSeleccionado!.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clienteSeleccionado == null
                                ? 'Toca para seleccionar un cliente'
                                : clienteSeleccionado!.nombre,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),

          // Lista de productos
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Botón agregar producto
                GestureDetector(
                  onTap: _agregarProducto,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add, color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Agregar productos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Estado vacío
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay productos agregados',
                          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Presiona "Agregar productos" para empezar',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                // Lista de productos
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _editarProducto(index),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.cantidadTotal}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nombreProducto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.tieneSabores)
                                    Text(
                                      item.cantidadPorSabor.entries.map((e) => '${e.key} (${e.value})').join(', '),
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '\$${_formatearPrecio(item.subtotal)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              ),
                              onPressed: () => _eliminarProducto(index),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Total
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? "producto" : "productos"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Text(
                      'Total:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '\$${_formatearPrecio(total)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Extension para centrar widgets
extension WidgetExtension on Widget {
  Widget wrapCenter() {
    return Center(child: this);
  }
}