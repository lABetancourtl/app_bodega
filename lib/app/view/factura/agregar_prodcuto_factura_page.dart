import 'dart:io';

import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:flutter/material.dart';

class AgregarProductoFacturaPage extends StatefulWidget {
  const AgregarProductoFacturaPage({super.key});

  @override
  State<AgregarProductoFacturaPage> createState() =>
      _AgregarProductoFacturaPageState();
}

class _AgregarProductoFacturaPageState extends State<AgregarProductoFacturaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<CategoriaModel> categorias = [];
  List<ProductoModel> productos = [];
  List<ProductoModel> productosFiltrados = [];
  int? _categoriaSeleccionadaId;
  int? _productoPresionadoId;
  late Future<void> _delayedAccion;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  void _cargarCategorias() async {
    final categoriasCargadas = await _dbHelper.obtenerCategorias();
    setState(() {
      categorias = categoriasCargadas;
      if (categorias.isNotEmpty) {
        _categoriaSeleccionadaId = categorias[0].id;
        _cargarProductos(categorias[0].id!);
      }
    });
  }

  void _cargarProductos(int categoriaId) async {
    final productosCargados = await _dbHelper.obtenerProductosPorCategoria(categoriaId);
    setState(() {
      productos = productosCargados;
      productosFiltrados = productosCargados;
    });
  }

  Widget _construirImagenProducto(String? imagenPath) {
    if (imagenPath != null && imagenPath.isNotEmpty) {
      final file = File(imagenPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 60,
            height: 60,
          ),
        );
      }
    }

    // Imagen por defecto si no existe
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

  void _verImagenProducto(ProductoModel producto) {
    if (producto.imagenPath != null && producto.imagenPath!.isNotEmpty) {
      final file = File(producto.imagenPath!);
      if (file.existsSync()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Imagen del Producto'),
                centerTitle: true,
              ),
              body: Center(
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este producto no tiene imagen')),
    );
  }

  void _mostrarDialogoCantidad(ProductoModel producto) {
    final TextEditingController cantidadTotalController = TextEditingController();
    final Map<String, TextEditingController> controllersPorSabor = {};
    final Map<String, int> cantidadPorSabor = {};

    // Inicializar controladores
    for (var sabor in producto.sabores) {
      cantidadPorSabor[sabor] = 0;
      controllersPorSabor[sabor] = TextEditingController(text: '0');
    }

    showDialog(
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
                  // Cantidad Total
                  TextField(
                    controller: cantidadTotalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cantidad Total',
                      hintText: 'Ej: 12',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.inventory),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Distribución por sabores (si tiene múltiples sabores)
                  if (producto.sabores.length > 1) ...[
                    const Text(
                      'Distribuir por sabor:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ...producto.sabores.map((sabor) {
                      final controller = controllersPorSabor[sabor]!;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(sabor),
                            ),
                            SizedBox(
                              width: 70,
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
                                    vertical: 8,
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
                    const SizedBox(height: 12),
                    Text(
                      'Total asignado: ${cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
                  if (cantidadTotalController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor ingresa la cantidad')),
                    );
                    return;
                  }

                  final cantidadTotal = int.parse(cantidadTotalController.text);

                  if (producto.sabores.length > 1) {
                    final cantidadAsignada =
                    cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);

                    if (cantidadAsignada != cantidadTotal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'La suma de sabores ($cantidadAsignada) debe ser igual a $cantidadTotal',
                          ),
                        ),
                      );
                      return;
                    }
                  }

                  final itemFactura = ItemFacturaModel(
                    productoId: producto.id!,
                    nombreProducto: producto.nombre,
                    precioUnitario: producto.precio,
                    cantidadTotal: cantidadTotal,
                    cantidadPorSabor: producto.sabores.length > 1
                        ? cantidadPorSabor
                        : {producto.sabores[0]: cantidadTotal},
                    tieneSabores: producto.sabores.length > 1,
                  );

                  Navigator.pop(context);
                  Navigator.pop(context, itemFactura);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Agregar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Producto'),
      ),
      body: Column(
        children: [
          // Fila de categorías
          if (categorias.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];
                  final isSelected = _categoriaSeleccionadaId == categoria.id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(categoria.nombre),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _categoriaSeleccionadaId = categoria.id;
                          _cargarProductos(categoria.id!);
                        });
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Padding y título
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecciona un producto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Lista de productos
          Expanded(
            child: productosFiltrados.isEmpty
                ? const Center(
              child: Text('No hay productos en esta categoría'),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: productosFiltrados.length,
              itemBuilder: (context, index) {
                final producto = productosFiltrados[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: _construirImagenProducto(producto.imagenPath),
                    title: Text(
                      producto.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Sabores: ${producto.sabores.join(', ')}',
                    ),
                    trailing: const Icon(Icons.add_circle, color: Colors.blue),
                    onTap: () => _mostrarDialogoCantidad(producto),
                    onLongPress: () => _verImagenProducto(producto),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}