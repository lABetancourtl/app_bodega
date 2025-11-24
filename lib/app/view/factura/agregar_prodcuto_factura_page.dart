import 'package:app_bodega/app/datasources/database_helper.dart';
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

  List<ProductoModel> productos = [];
  ProductoModel? productoSeleccionado;

  final TextEditingController _cantidadTotalController = TextEditingController();
  Map<String, int> cantidadPorSabor = {};
  Map<String, TextEditingController> controllersPorSabor = {}; // Nuevo: Controladores para cada sabor

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  void _cargarProductos() async {
    final productosCargados = await _dbHelper.obtenerProductos();
    setState(() {
      productos = productosCargados;
    });
  }

  void _seleccionarProducto(ProductoModel producto) {
    // Limpiar controladores anteriores
    for (var controller in controllersPorSabor.values) {
      controller.dispose();
    }
    controllersPorSabor.clear();

    setState(() {
      productoSeleccionado = producto;
      _cantidadTotalController.clear();
      cantidadPorSabor.clear();

      // Inicializar cantidadPorSabor y controllersPorSabor para cada sabor
      for (var sabor in producto.sabores) {
        cantidadPorSabor[sabor] = 0;
        controllersPorSabor[sabor] = TextEditingController(text: '0');
      }
    });
  }

  void _actualizarCantidadSabor(String sabor, int cantidad) {
    setState(() {
      cantidadPorSabor[sabor] = cantidad;
    });
  }

  void _agregarProductoAFactura() {
    if (productoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un producto')),
      );
      return;
    }

    if (_cantidadTotalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa la cantidad total')),
      );
      return;
    }

    final cantidadTotal = int.parse(_cantidadTotalController.text);

    if (productoSeleccionado!.sabores.length > 1) {
      final cantidadAsignada = cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);

      if (cantidadAsignada != cantidadTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La suma de sabores ($cantidadAsignada) debe ser igual a la cantidad total ($cantidadTotal)',
            ),
          ),
        );
        return;
      }
    }

    final itemFactura = ItemFacturaModel(
      productoId: productoSeleccionado!.id!,
      nombreProducto: productoSeleccionado!.nombre,
      precioUnitario: productoSeleccionado!.precio,
      cantidadTotal: cantidadTotal,
      cantidadPorSabor: productoSeleccionado!.sabores.length > 1
          ? cantidadPorSabor
          : {productoSeleccionado!.sabores[0]: cantidadTotal},
      tieneSabores: productoSeleccionado!.sabores.length > 1,
    );

    Navigator.pop(context, itemFactura);
  }

  @override
  void dispose() {
    _cantidadTotalController.dispose();
    // Limpiar todos los controladores de sabores
    for (var controller in controllersPorSabor.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lista de productos
            const Text(
              'Selecciona un producto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...productos.map((producto) {
              final isSelected = productoSeleccionado?.id == producto.id;
              return GestureDetector(
                onTap: () => _seleccionarProducto(producto),
                child: Card(
                  color: isSelected ? Colors.blue[50] : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.local_drink, color: Colors.blue),
                    title: Text(producto.nombre),
                    subtitle: Text(
                      'Sabores: ${producto.sabores.join(', ')}',
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),

            if (productoSeleccionado != null) ...[
              // Cantidad Total
              TextFormField(
                controller: _cantidadTotalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad Total',
                  hintText: 'Ej: 12',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.inventory),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),

              // Distribución por sabores (si tiene múltiples sabores)
              if (productoSeleccionado!.sabores.length > 1) ...[
                const Text(
                  'Distribuir cantidad por sabor',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...productoSeleccionado!.sabores.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String sabor = entry.value;
                  TextEditingController controller = controllersPorSabor[sabor]!;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(sabor),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: controller,
                            keyboardType: TextInputType.number,
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
                              // Borrar el 0 cuando el usuario seleccione el campo
                              if (controller.text == '0') {
                                controller.clear();
                              }
                            },
                            onChanged: (value) {
                              final cantidad = int.tryParse(value) ?? 0;
                              _actualizarCantidadSabor(sabor, cantidad);
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
              const SizedBox(height: 32),

              // Botón Agregar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _agregarProductoAFactura,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'Agregar a Factura',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}