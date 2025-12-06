import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';

class CrearFacturaLimpiaPage extends StatefulWidget {
  const CrearFacturaLimpiaPage({super.key});

  @override
  State<CrearFacturaLimpiaPage> createState() => _CrearFacturaLimpiaPageState();
}

class _CrearFacturaLimpiaPageState extends State<CrearFacturaLimpiaPage> {
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

  void _mostrarFormularioCliente() async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(
      text: clienteSeleccionado?.nombre ?? '',
    );
    final negocioController = TextEditingController(
      text: clienteSeleccionado?.nombreNegocio ?? '',
    );
    final direccionController = TextEditingController(
      text: clienteSeleccionado?.direccion ?? '',
    );
    final telefonoController = TextEditingController(
      text: clienteSeleccionado?.telefono ?? '',
    );
    final observacionesController = TextEditingController(
      text: clienteSeleccionado?.observaciones ?? '',
    );

    final resultado = await showModalBottomSheet<ClienteModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(
                  children: [
                    const Icon(Icons.person_add,),
                    const SizedBox(width: 8),
                    const Text(
                      'Datos del Cliente',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa la información del cliente',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Nombre del cliente (requerido)
                TextFormField(
                  controller: nombreController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Cliente',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre del cliente es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nombre del negocio (requerido)
                TextFormField(
                  controller: negocioController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Negocio',
                    prefixIcon: const Icon(Icons.store),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre del negocio es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Dirección (requerido)
                TextFormField(
                  controller: direccionController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La dirección es requerida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Teléfono (requerido)
                TextFormField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El teléfono es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Observaciones (opcional)
                TextFormField(
                  controller: observacionesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observaciones',
                    prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          // Crear cliente temporal
                          final clienteTemporal = ClienteModel(
                            id: null, // Sin ID = temporal
                            nombre: nombreController.text.trim(),
                            nombreNegocio: negocioController.text.trim(),
                            direccion: direccionController.text.trim(),
                            telefono: telefonoController.text.trim(),
                            ruta: Ruta.ruta1, // Ruta por defecto
                            observaciones: observacionesController.text.trim().isEmpty
                                ? null
                                : observacionesController.text.trim(),
                          );

                          Navigator.pop(context, clienteTemporal);
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        clienteSeleccionado = resultado;
      });
    }
  }

  void _agregarProducto() async {

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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${resultado.length} ${resultado.length == 1 ? "producto procesado" : "productos procesados"}'),
              duration: const Duration(milliseconds: 1500),
              backgroundColor: Colors.black45,
            ),
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto agregado'),
              duration: Duration(milliseconds: 1500),
              backgroundColor: Colors.black45,
            ),
          );
        }
      });
    }
  }

  void _eliminarProducto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Deseas eliminar "${items[index].nombreProducto}" de la factura?'),
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

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Producto eliminado'),
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

  void _guardarFactura() async {
    if (clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los datos del cliente')),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor agrega al menos un producto')),
      );
      return;
    }

    final factura = FacturaModel(
      clienteId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factura guardada para ${clienteSeleccionado!.nombre}'),
            duration: Duration(milliseconds: 1500),
            backgroundColor: Colors.black45,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          duration: Duration(milliseconds: 1500),
          backgroundColor: Colors.black45,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = items.fold(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Factura',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _guardarFactura,
            tooltip: 'Guardar factura',
          ),
        ],
      ),
      body: Column(
        children: [
          // Datos del Cliente
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _mostrarFormularioCliente,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: clienteSeleccionado == null ? Colors.black54 : Colors.green,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: clienteSeleccionado == null
                      ? Colors.grey.shade200
                      : Colors.green.shade50,
                ),
                child: Row(
                  children: [
                    Icon(
                      clienteSeleccionado == null ? Icons.warning : Icons.check_circle,
                      color: clienteSeleccionado == null ? Colors.black54 : Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clienteSeleccionado == null
                                ? 'Datos del Cliente'
                                : clienteSeleccionado!.nombreNegocio,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            clienteSeleccionado == null
                                ? 'Toca aquí para ingresar los datos'
                                : '${clienteSeleccionado!.nombre} • ${clienteSeleccionado!.telefono}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit,
                      color: clienteSeleccionado == null ? Colors.black54 : Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Lista de productos
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // Botón agregar producto
                GestureDetector(
                  onTap: _agregarProducto,
                  child: Card(
                    color: Colors.lightGreen[50],
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 30, color: Colors.grey[700]),
                          const SizedBox(width: 12),
                          Text(
                            "Agregar productos",
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
                      child: Text(
                        'No hay productos agregados\nPresiona "Agregar productos" para empezar',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? "producto" : "productos"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Text(
                      'Total: ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${_formatearPrecio(total)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _editarProducto(int index) async {
    final itemActual = items[index];
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

    final itemEditado = await _mostrarDialogoEdicion(producto, itemActual);

    if (itemEditado != null) {
      setState(() {
        items[index] = itemEditado;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto actualizado'),
          duration: Duration(seconds: 1),
        ),
      );
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
}