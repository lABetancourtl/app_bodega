import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
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

  void _editarProducto(int index) async {
    final itemActual = items[index];

    // Obtener información del producto desde la base de datos
    final producto = await _dbHelper.obtenerProductoPorId(itemActual.productoId);

    if (producto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el producto')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Mostrar el modal de edición
    final itemEditado = await _mostrarDialogoEdicion(producto, itemActual);

    if (itemEditado != null) {
      setState(() {
        items[index] = itemEditado;
      });
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

    // Inicializar controllers con valores actuales
    for (var sabor in producto.sabores) {
      final cantidad = cantidadPorSabor[sabor] ?? 0;
      controllersPorSabor[sabor] = TextEditingController(text: cantidad.toString());
    }

    // Función para calcular el total
    int calcularTotal() {
      return cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);
    }

    // Función para formatear precio
    String formatearPrecio(double precio) {
      final precioInt = precio.toInt();
      return precioInt.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (match) => '.',
      );
    }

    return await showDialog<ItemFacturaModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(producto.nombre),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PRODUCTO CON UN SOLO SABOR
                  if (producto.sabores.length == 1) ...[
                    TextField(
                      controller: cantidadTotalController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        hintText: 'Ej: 12',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],

                  // PRODUCTO CON MÚLTIPLES SABORES
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
                                  controller.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: controller.text.length,
                                  );
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
                    // Unidades (texto simple)
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
                    // Total en precio
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
                            '\$${formatearPrecio(calcularTotal() * producto.precio)}',
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  int cantidadTotal;

                  // Validar según tipo de producto
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
            ],
          );
        },
      ),
    );
  }

  void _eliminarProducto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de que deseas eliminar ${items[index].nombreProducto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                items.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _guardarCambios() async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos un producto')),
      );
      return;
    }

    final facturaActualizada = FacturaModel(
      id: widget.factura.id,
      clienteId: widget.factura.clienteId,
      nombreCliente: widget.factura.nombreCliente,
      fecha: widget.factura.fecha,
      items: items,
      estado: widget.factura.estado,
      negocioCliente: widget.factura.negocioCliente,
      direccionCliente: widget.factura.direccionCliente,
      observacionesCliente: widget.factura.observacionesCliente,
    );

    try {
      await _dbHelper.actualizarFactura(facturaActualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Factura actualizada para ${widget.factura.nombreCliente}')),
        );
        Navigator.pop(context, facturaActualizada);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
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
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    // Botón agregar producto (siempre visible)
                    GestureDetector(
                      onTap: _agregarProducto,
                      child: Card(
                        color: Colors.lightGreen[50],
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children:  [
                              Icon(Icons.add, size: 30, color: Colors.grey[700]),
                              SizedBox(width: 12),
                              Text(
                                "Agregar producto",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Si no hay productos
                    if (items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No hay productos agregados'),
                        ),
                      ),

                    // Lista de productos
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

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
                                  'Sabores: ${item.cantidadPorSabor.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
                                  style: const TextStyle(fontSize: 12),
                                )
                              else
                                Text('Cantidad: ${item.cantidadTotal}'),
                              Text(
                                'Subtotal: \$${_formatearPrecio(item.subtotal)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarProducto(index),
                          ),
                          onTap: () => _editarProducto(index),
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
          // Positioned(
          //   right: 16,
          //   bottom: 74 +
          //       MediaQuery.of(context).viewInsets.bottom +
          //       MediaQuery.of(context).padding.bottom,
          //   child: FloatingActionButton(
          //     onPressed: _agregarProducto,
          //     child: const Icon(Icons.add),
          //   ),
          // ),
        ],
      ),
    );
  }
}