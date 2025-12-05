import 'dart:io';
import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CarritoProductosPage extends ConsumerWidget {
  const CarritoProductosPage({super.key});

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  Future<void> _editarProducto(
      BuildContext context,
      WidgetRef ref,
      int index,
      ItemFacturaModel itemActual,
      ) async {
    final dbHelper = DatabaseHelper();

    // Obtener información del producto desde la base de datos
    final producto = await dbHelper.obtenerProductoPorId(itemActual.productoId);

    if (producto == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el producto')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Mostrar el modal de edición (igual al de agregar)
    final itemEditado = await _mostrarDialogoEdicion(context, producto, itemActual);

    if (itemEditado != null) {
      // Actualizar el carrito
      final carritoProvider = ref.read(carritoTemporalProvider.notifier);
      final carritoActual = ref.read(carritoTemporalProvider);
      final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);
      nuevoCarrito[index] = itemEditado;
      carritoProvider.state = nuevoCarrito;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto actualizado'),
            duration: Duration(seconds: 1),
          ),
        );
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

    // Inicializar controllers con valores actuales
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.inventory),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${int.tryParse(cantidadTotalController.text) ?? 0} unidades',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '\$${_formatearPrecio((int.tryParse(cantidadTotalController.text) ?? 0) * producto.precio)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (producto.sabores.length > 1) ...[
                          const Text(
                            'Distribuir por sabor:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                      style: const TextStyle(fontSize: 15),
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${calcularTotal()} unidades',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '\$${_formatearPrecio(calcularTotal() * producto.precio)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              int cantidadTotal;
                              if (producto.sabores.length == 1) {
                                if (cantidadTotalController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Por favor ingresa la cantidad')),
                                  );
                                  return;
                                }
                                cantidadTotal = int.parse(cantidadTotalController.text);
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
                                cantidadPorSabor: producto.sabores.length > 1
                                    ? cantidadPorSabor
                                    : {producto.sabores[0]: cantidadTotal},
                                tieneSabores: producto.sabores.length > 1,
                              );
                              Navigator.pop(context, itemActualizado);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: const Text(
                              'Guardar',
                              style: TextStyle(color: Colors.white),
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

  void _eliminarProducto(BuildContext context, WidgetRef ref, int index, String nombreProducto) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Deseas eliminar "$nombreProducto" del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final carritoProvider = ref.read(carritoTemporalProvider.notifier);
              final carritoActual = ref.read(carritoTemporalProvider);
              final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);
              nuevoCarrito.removeAt(index);
              carritoProvider.state = nuevoCarrito;

              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Producto eliminado del carrito'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _finalizarSeleccion(BuildContext context, WidgetRef ref) {
    final carrito = ref.read(carritoTemporalProvider);

    if (carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Retornar todos los productos seleccionados
    Navigator.pop(context, carrito);
  }

  void _vaciarCarrito(BuildContext context, WidgetRef ref) {
    final carrito = ref.read(carritoTemporalProvider);

    if (carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito ya está vacío'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: Text('¿Deseas eliminar todos los productos del carrito? (${carrito.length} productos)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(carritoTemporalProvider.notifier).state = [];
              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Carrito vaciado'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text(
              'Vaciar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirImagenProducto(String? imagenPath) {
    if (imagenPath != null && imagenPath.isNotEmpty && imagenPath.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imagenPath,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _imagenPorDefecto();
          },
        ),
      );
    }
    return _imagenPorDefecto();
  }

  Widget _imagenPorDefecto() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.local_drink,
        color: Colors.blue[600],
        size: 32,
      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoTemporalProvider);
    final total = carrito.fold<double>(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Productos'),
        actions: [
          if (carrito.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _vaciarCarrito(context, ref),
              tooltip: 'Vaciar carrito',
            ),
        ],
      ),
      body: carrito.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'El carrito está vacío',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega productos para continuar',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Lista de productos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: carrito.length,
              itemBuilder: (context, index) {
                final item = carrito[index];
                // Filtrar sabores con cantidad mayor a 0
                final saboresConCantidad = item.cantidadPorSabor.entries
                    .where((entry) => entry.value > 0)
                    .toList();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: FutureBuilder<String?>(
                          future: _obtenerImagenProducto(item.productoId),
                          builder: (context, snapshot) {
                            Widget imagenWidget;

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              // Mostrar indicador de carga mientras se obtiene la imagen
                              imagenWidget = Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              // Mostrar la imagen o el ícono por defecto
                              imagenWidget = _construirImagenProducto(snapshot.data);
                            }

                            return Stack(
                              children: [
                                imagenWidget,
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        title: Text(
                          item.nombreProducto,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mostrar sabores con cantidad mayor a 0
                            if (saboresConCantidad.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              ...saboresConCantidad.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '${entry.key}: ${entry.value}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              )),
                            ] else if (!item.tieneSabores) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Cantidad: ${item.cantidadTotal}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarProducto(
                            context,
                            ref,
                            index,
                            item.nombreProducto,
                          ),
                        ),
                        onTap: () => _editarProducto(context, ref, index, item),
                      ),
                      // Footer del card con info del carrito
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${item.cantidadTotal} en carrito',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Subtotal: \$${_formatearPrecio(item.subtotal)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Total y botones
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${carrito.length} ${carrito.length == 1 ? "producto" : "productos"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Text(
                            'TOTAL:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${_formatearPrecio(total)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Seguir Comprando'),
                          style: OutlinedButton.styleFrom(
                            // padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _finalizarSeleccion(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ), child: Text(
                              'Finalizar',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white
                              ),
                        ),
                        ),

                        // ElevatedButton(
                        //   onPressed: _guardarCategoria,
                        //   style: ElevatedButton.styleFrom(
                        //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        //     backgroundColor: Colors.blue,
                        //   ),
                        //   child: const Text(
                        //     'Guardar Categoría',
                        //     style: TextStyle(fontSize: 16, color: Colors.white),
                        //   ),
                        // ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}