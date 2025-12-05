import 'dart:io';
import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/service/cache_manager.dart';
import 'package:app_bodega/app/view/factura/carrito_productos_page.dart';
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

// Provider para el carrito temporal
final carritoTemporalProvider = StateProvider<List<ItemFacturaModel>>((ref) => []);

// ============= PÁGINA =============
class AgregarProductoFacturaPage extends ConsumerStatefulWidget {
  final List<ItemFacturaModel>? itemsIniciales;

  const AgregarProductoFacturaPage({
    super.key,
    this.itemsIniciales,
  });

  @override
  ConsumerState<AgregarProductoFacturaPage> createState() => _AgregarProductoFacturaPageState();
}

class _AgregarProductoFacturaPageState extends ConsumerState<AgregarProductoFacturaPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Precargar el carrito con items iniciales o limpiarlo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.itemsIniciales != null && widget.itemsIniciales!.isNotEmpty) {
        ref.read(carritoTemporalProvider.notifier).state =
        List<ItemFacturaModel>.from(widget.itemsIniciales!);
      } else {
        ref.read(carritoTemporalProvider.notifier).state = [];
      }
    });
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

  void _finalizarSeleccion() {
    final carrito = ref.read(carritoTemporalProvider);

    if (carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No has agregado ningún producto'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Retornar todos los productos seleccionados
    Navigator.pop(context, carrito);
  }

  void _mostrarCarrito() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CarritoProductosPage(),
      ),
    ).then((resultado) {
      // Si se retorna algo desde el carrito (finalizar), lo devolvemos
      if (resultado != null) {
        Navigator.pop(context, resultado);
      }
    });
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

    // Obtener el carrito actual para verificar qué productos están agregados
    final carrito = ref.watch(carritoTemporalProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];

        // Buscar si este producto ya está en el carrito
        final itemEnCarrito = carrito.firstWhere(
              (item) => item.productoId == producto.id,
          orElse: () => ItemFacturaModel(
            productoId: '',
            nombreProducto: '',
            precioUnitario: 0,
            cantidadTotal: 0,
            cantidadPorSabor: {},
            tieneSabores: false,
          ),
        );

        final estaEnCarrito = itemEnCarrito.productoId.isNotEmpty;

        return _ProductoCard(
          producto: producto,
          estaEnCarrito: estaEnCarrito,
          itemEnCarrito: estaEnCarrito ? itemEnCarrito : null,
          onSelected: (item) {
            // Agregar o actualizar en el carrito
            final carritoActual = ref.read(carritoTemporalProvider);
            final indexExistente = carritoActual.indexWhere(
                  (elemento) => elemento.productoId == item.productoId,
            );

            if (indexExistente != -1) {
              // Actualizar el producto existente
              final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);
              nuevoCarrito[indexExistente] = item;
              ref.read(carritoTemporalProvider.notifier).state = nuevoCarrito;
            } else {
              // Agregar nuevo producto
              ref.read(carritoTemporalProvider.notifier).state =
              List.from(carritoActual)..add(item);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final categoriaIndex = ref.watch(categoriaIndexProvider);
    final carrito = ref.watch(carritoTemporalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Productos'),
        actions: [
          // Botón del carrito
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _mostrarCarrito,
              ),
              if (carrito.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${carrito.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
              // Dropdown de categorías
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: categoriaIndex,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                    menuMaxHeight: 400,
                    alignment: AlignmentDirectional.bottomStart,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    items: categorias.asMap().entries.map((entry) {
                      final index = entry.key;
                      final categoria = entry.value;
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Row(
                          children: [
                            const Icon(Icons.category, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Text(categoria.nombre),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (int? nuevoIndex) {
                      if (nuevoIndex != null) {
                        ref.read(categoriaIndexProvider.notifier).state = nuevoIndex;
                        _pageController.animateToPage(
                          nuevoIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
              ),

              // PageView con las listas de productos
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

// ============= WIDGET DE TARJETA DE PRODUCTO =============
class _ProductoCard extends StatelessWidget {
  final ProductoModel producto;
  final Function(ItemFacturaModel) onSelected;
  final bool estaEnCarrito;
  final ItemFacturaModel? itemEnCarrito;

  const _ProductoCard({
    required this.producto,
    required this.onSelected,
    this.estaEnCarrito = false,
    this.itemEnCarrito,
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

    // Inicializar con los valores del carrito si existe
    if (estaEnCarrito && itemEnCarrito != null) {
      if (producto.sabores.length == 1) {
        cantidadTotalController.text = itemEnCarrito!.cantidadTotal.toString();
      } else {
        // Cargar las cantidades por sabor del item en carrito
        for (var sabor in producto.sabores) {
          final cantidadGuardada = itemEnCarrito!.cantidadPorSabor[sabor] ?? 0;
          cantidadPorSabor[sabor] = cantidadGuardada;
          controllersPorSabor[sabor] = TextEditingController(
            text: cantidadGuardada.toString(),
          );
        }
      }
    } else {
      // Inicializar en 0 si es un producto nuevo
      for (var sabor in producto.sabores) {
        cantidadPorSabor[sabor] = 0;
        controllersPorSabor[sabor] = TextEditingController(text: '0');
      }
    }

    int calcularTotal() {
      return cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);
    }

    showModalBottomSheet(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            producto.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (estaEnCarrito)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: const Text(
                              'Editando',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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
                            autofocus: !estaEnCarrito,
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
                            child: Text(
                              estaEnCarrito ? 'Actualizar' : 'Agregar',
                              style: const TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        child: Column(
          children: [
            ListTile(
              leading: Stack(
                children: [
                  _construirImagenProducto(producto.imagenPath),
                  if (estaEnCarrito)
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
              ),
              title: Text(
                producto.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              trailing: Icon(
                estaEnCarrito ? Icons.edit : Icons.add_shopping_cart,
                color: estaEnCarrito ? Colors.green : Colors.black54,
              ),
              onTap: () => _mostrarDialogoCantidad(context, producto),
              onLongPress: () => _verImagenProducto(context, producto),
            ),
            // Mostrar información si está en el carrito
            if (estaEnCarrito && itemEnCarrito != null)
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
                          '${itemEnCarrito!.cantidadTotal} en carrito',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Subtotal: \${_formatearPrecio(itemEnCarrito!.subtotal)}',
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
      ),
    );
  }
}