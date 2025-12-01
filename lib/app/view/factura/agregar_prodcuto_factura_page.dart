import 'dart:io';
import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/service/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============= PROVIDERS =============
final categoriasProvider = FutureProvider<List<CategoriaModel>>((ref) async {
  final dbHelper = DatabaseHelper();
  return await dbHelper.obtenerCategorias();
});

final categoriaIndexProvider = StateProvider<int>((ref) => 0);

final categoriaSeleccionadaProvider = Provider<String?>((ref) {
  final categoriasAsync = ref.watch(categoriasProvider);
  final index = ref.watch(categoriaIndexProvider);
  return categoriasAsync.maybeWhen(
    data: (categorias) {
      if (categorias.isEmpty || index >= categorias.length) return null;
      return categorias[index].id;
    },
    orElse: () => null,
  );
});

final productosPorCategoriaProvider = FutureProvider.family<List<ProductoModel>, String>((ref, categoriaId) async {
  final dbHelper = DatabaseHelper();
  return await dbHelper.obtenerProductosPorCategoria(categoriaId);
});

// ============= PÁGINA =============
class AgregarProductoFacturaPage extends ConsumerStatefulWidget {
  const AgregarProductoFacturaPage({super.key});

  @override
  ConsumerState<AgregarProductoFacturaPage> createState() => _AgregarProductoFacturaPageState();
}

class _AgregarProductoFacturaPageState extends ConsumerState<AgregarProductoFacturaPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
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

  void _verImagenProducto(BuildContext context, ProductoModel producto) {
    if (producto.imagenPath != null && producto.imagenPath!.isNotEmpty) {
      if (producto.imagenPath!.startsWith('http')) {
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
                  child: Image.network(
                    producto.imagenPath!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
        return;
      } else {
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
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este producto no tiene imagen')),
    );
  }

  Widget _construirListaProductos(List<ProductoModel> productos, List<CategoriaModel> categorias) {
    if (productos.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_drink_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos en esta categoría',
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
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        return _ProductoCard(
          producto: producto,
          onSelected: (item) {
            Navigator.pop(context, item);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final categoriaIndex = ref.watch(categoriaIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Producto'),
      ),
      body: categoriasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (categorias) {
          if (categorias.isEmpty) {
            return const Center(
              child: Text('No hay categorías disponibles'),
            );
          }

          if (categoriaIndex >= categorias.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(categoriaIndexProvider.notifier).state = 0;
              _pageController.jumpToPage(0);
            });
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: categorias.length,
                    itemBuilder: (context, index) {
                      final categoria = categorias[index];
                      final isSelected = categoriaIndex == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(categoria.nombre),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(categoriaIndexProvider.notifier).state = index;
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
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
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: categorias.length,
                  onPageChanged: (index) {
                    ref.read(categoriaIndexProvider.notifier).state = index;
                  },
                  itemBuilder: (context, pageIndex) {
                    final categoria = categorias[pageIndex];
                    final productosAsync = ref.watch(productosPorCategoriaProvider(categoria.id!));

                    return productosAsync.when(
                      loading: () => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Cargando productos...'),
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
                      data: (productos) {
                        return _construirListaProductos(productos, categorias);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final ProductoModel producto;
  final Function(ItemFacturaModel) onSelected;

  const _ProductoCard({
    required this.producto,
    required this.onSelected,
  });

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

  void _verImagenProducto(BuildContext context, ProductoModel producto) {
    if (producto.imagenPath != null && producto.imagenPath!.isNotEmpty) {
      if (producto.imagenPath!.startsWith('http')) {
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
                  child: Image.network(
                    producto.imagenPath!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
        return;
      } else {
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
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este producto no tiene imagen')),
    );
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  void _mostrarDialogoCantidad(BuildContext context, ProductoModel producto) {
    final TextEditingController cantidadTotalController = TextEditingController();
    final Map<String, TextEditingController> controllersPorSabor = {};
    final Map<String, int> cantidadPorSabor = {};

    for (var sabor in producto.sabores) {
      cantidadPorSabor[sabor] = 0;
      controllersPorSabor[sabor] = TextEditingController(text: '0');
    }

    int calcularTotal() {
      return cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);
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
                  onSelected(itemFactura);
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListTile(
        leading: _construirImagenProducto(producto.imagenPath),
        title: Text(
          producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sabor${producto.sabores.length > 1 ? 'es' : ''}: ${producto.sabores.join(', ')}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Precio: \$${_formatearPrecio(producto.precio)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (producto.cantidadPorPaca != null)
              Text(
                'Cantidad por paca: ${producto.cantidadPorPaca}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.add_circle, color: Colors.blue),
        onTap: () => _mostrarDialogoCantidad(context, producto),
        onLongPress: () => _verImagenProducto(context, producto),
      ),
    );
  }
}
