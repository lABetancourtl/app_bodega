import 'dart:io';

import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/prodcut/crear_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/crear_producto_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_prodcuto_page.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../barcode/barcode_scaner_page.dart' as scanner;

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

// <CHANGE> Provider para resaltar producto encontrado por código de barras
final productoResaltadoProvider = StateProvider<String?>((ref) => null);

// <CHANGE> Provider para el índice del producto a hacer scroll
final productoIndexScrollProvider = StateProvider<int?>((ref) => null);

// ============= PÁGINA =============
class ProductosPage extends ConsumerStatefulWidget {
  const ProductosPage({super.key});

  @override
  ConsumerState<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends ConsumerState<ProductosPage> {
  late PageController _pageController;

  // <CHANGE> Mapa de ScrollControllers para cada categoría
  final Map<int, ScrollController> _scrollControllers = {};

  ScrollController _getScrollController(int index) {
    if (!_scrollControllers.containsKey(index)) {
      _scrollControllers[index] = ScrollController();
    }
    return _scrollControllers[index]!;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // <CHANGE> Limpiar todos los ScrollControllers
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  // <CHANGE> Método para escanear código de barras
  void _escanearCodigoBarras(BuildContext context, List<CategoriaModel> categorias) async {
    final codigoBarras = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const scanner.BarcodeScannerPage(),
      ),
    );

    if (codigoBarras != null && codigoBarras.isNotEmpty) {
      _buscarProductoPorCodigoBarras(codigoBarras, categorias);
    }
  }

  // <CHANGE> Método para buscar producto por código de barras
  void _buscarProductoPorCodigoBarras(String codigoBarras, List<CategoriaModel> categorias) async {
    final dbHelper = DatabaseHelper();

    try {
      final producto = await dbHelper.obtenerProductoPorCodigoBarras(codigoBarras);

      if (producto != null) {
        // Vibración de éxito
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 100, 50, 100], intensities: [0, 200, 0, 255]);
        }
        // Buscar el índice de la categoría del producto
        final categoriaIndex = categorias.indexWhere((cat) => cat.id == producto.categoriaId);

        if (categoriaIndex != -1) {
          // Navegar a la categoría del producto
          ref.read(categoriaIndexProvider.notifier).state = categoriaIndex;
          _pageController.animateToPage(
            categoriaIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          // Resaltar el producto encontrado
          ref.read(productoResaltadoProvider.notifier).state = producto.id;

          // <CHANGE> Obtener el índice del producto para hacer scroll
          final productosEnCategoria = await dbHelper.obtenerProductosPorCategoria(producto.categoriaId);
          final productoIndex = productosEnCategoria.indexWhere((p) => p.id == producto.id);
          if (productoIndex != -1) {
            ref.read(productoIndexScrollProvider.notifier).state = productoIndex;
          }

          // Quitar el resaltado después de 2 segundos
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) {
              ref.read(productoResaltadoProvider.notifier).state = null;
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Producto encontrado: ${producto.nombre}'),
                backgroundColor: Colors.black54,
                duration: const Duration(milliseconds: 1300),
              ),
            );
          }
        }
      } else {
        // Vibración de error
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 300, 100, 300], intensities: [0, 128, 0, 128]);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se encontró producto con código: $codigoBarras'),
              backgroundColor: Colors.black54,
              duration: const Duration(milliseconds: 1300),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al buscar producto: $e'),
            backgroundColor: Colors.black54,
            duration: const Duration(milliseconds: 1300),
          ),
        );
      }
    }
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
      child: const Icon(
        Icons.image_rounded,
        size: 32,
      ),
    );
  }

  void _crearCategoria(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final nuevaCategoria = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CrearCategoriaPage(),
      ),
    );

    if (nuevaCategoria != null) {
      try {
        await dbHelper.insertarCategoria(nuevaCategoria);
        ref.invalidate(categoriasProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categoría ${nuevaCategoria.nombre} creada')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _editarCategoria(BuildContext context, CategoriaModel categoria) async {
    final dbHelper = DatabaseHelper();
    final categoriaActualizada = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarCategoriaPage(categoria: categoria),
      ),
    );

    if (categoriaActualizada != null) {
      try {
        await dbHelper.actualizarCategoria(categoriaActualizada);
        ref.invalidate(categoriasProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categoría ${categoriaActualizada.nombre} actualizada')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _eliminarCategoria(BuildContext context, CategoriaModel categoria) {
    final dbHelper = DatabaseHelper();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro de que deseas eliminar ${categoria.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await dbHelper.eliminarCategoria(categoria.id!);
                ref.invalidate(categoriasProvider);

                final currentIndex = ref.read(categoriaIndexProvider);
                if (currentIndex > 0) {
                  ref.read(categoriaIndexProvider.notifier).state = currentIndex - 1;
                  _pageController.jumpToPage(currentIndex - 1);
                }

                Navigator.pop(context);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Categoría ${categoria.nombre} eliminada')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _crearProducto(BuildContext context, List<CategoriaModel> categorias) async {
    final dbHelper = DatabaseHelper();
    final nuevoProducto = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearProductoPage(categorias: categorias),
      ),
    );

    if (nuevoProducto != null) {
      try {
        await dbHelper.insertarProducto(nuevoProducto);
        ref.invalidate(productosPorCategoriaProvider(nuevoProducto.categoriaId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto ${nuevoProducto.nombre} creado')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _eliminarProducto(BuildContext context, ProductoModel producto) {
    final dbHelper = DatabaseHelper();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de que deseas eliminar ${producto.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await dbHelper.eliminarProducto(producto.id!);
                ref.invalidate(productosPorCategoriaProvider(producto.categoriaId));
                Navigator.pop(context);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Producto ${producto.nombre} eliminado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuFlotante(BuildContext context, List<CategoriaModel> categorias) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Opciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Crear Categoría'),
              onTap: () {
                Navigator.pop(context);
                _crearCategoria(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_drink_outlined),
              title: const Text('Crear Producto'),
              onTap: () {
                Navigator.pop(context);
                _crearProducto(context, categorias);
              },
            ),
          ],
        ),
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

  // <CHANGE> Método modificado para incluir resaltado de producto
  Widget _construirListaProductos(List<ProductoModel> productos, List<CategoriaModel> categorias, int categoriaIndex) {
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

    // <CHANGE> Obtener el ScrollController para esta categoría
    final scrollController = _getScrollController(categoriaIndex);

    return Consumer(
      builder: (context, ref, child) {
        final productoResaltado = ref.watch(productoResaltadoProvider);
        final productoIndexScroll = ref.watch(productoIndexScrollProvider);

        // <CHANGE> Hacer scroll automático cuando hay un producto resaltado
        if (productoResaltado != null && productoIndexScroll != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Altura aproximada de cada item (Card + margin)
            const double itemHeight = 100.0;
            final double scrollPosition = productoIndexScroll * itemHeight;

            if (scrollController.hasClients) {
              scrollController.animateTo(
                scrollPosition,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }

            // Limpiar el índice después de hacer scroll
            ref.read(productoIndexScrollProvider.notifier).state = null;
          });
        }

        return ListView.builder(
          controller: scrollController, // <CHANGE> Agregar controller
          padding: const EdgeInsets.all(8),
          itemCount: productos.length,
          itemBuilder: (context, index) {
            final producto = productos[index];
            final estaResaltado = productoResaltado == producto.id;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: estaResaltado
                    ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
                    : null,
              ),
              child: Card(
                elevation: estaResaltado ? 8 : 1,
                color: estaResaltado ? Colors.green.shade50 : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: estaResaltado
                      ? const BorderSide(color: Colors.green, width: 3)
                      : BorderSide.none,
                ),
                margin: EdgeInsets.zero,
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
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _mostrarOpcionesProducto(context, producto, categorias);
                  },
                  onLongPress: () => _verImagenProducto(context, producto),
                ),
              ),
            );
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
        title: const Text(
          'Productos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        actions: [
          categoriasAsync.maybeWhen(
            data: (categorias) => IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Buscar por código de barras',
              onPressed: () => _escanearCodigoBarras(context, categorias),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          categoriasAsync.maybeWhen(
            data: (categorias) => IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Crear nuevo',
              onPressed: () => _mostrarMenuFlotante(context, categorias),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: categoriasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (categorias) {
          if (categorias.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay categorías',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _crearCategoria(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Categoría'),
                  ),
                ],
              ),
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
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<int>(
                          value: categoriaIndex,
                          isExpanded: true,
                          hint: const Text('Selecciona una categoría'),
                          items: categorias.asMap().entries.map((entry) {
                            final index = entry.key;
                            final categoria = entry.value;
                            return DropdownMenuItem<int>(
                              value: index,
                              child: Row(
                                children: [
                                  const Icon(Icons.category, color: Colors.black54, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      categoria.nombre,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
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
                          buttonStyleData: ButtonStyleData(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                          ),
                          iconStyleData: const IconStyleData(
                            icon: Icon(Icons.arrow_drop_down),
                            iconSize: 24,
                            iconEnabledColor: Colors.black,
                          ),
                          dropdownStyleData: DropdownStyleData(
                            maxHeight: 400,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            elevation: 8,
                            direction: DropdownDirection.textDirection,
                            offset: const Offset(0, -4),
                            scrollbarTheme: ScrollbarThemeData(
                              radius: const Radius.circular(40),
                              thickness: WidgetStateProperty.all(6),
                              thumbVisibility: WidgetStateProperty.all(true),
                            ),
                          ),
                          menuItemStyleData: const MenuItemStyleData(
                            height: 48,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.black54),
                        onPressed: () {
                          final categoria = categorias[categoriaIndex];
                          _mostrarOpcionesCategoria(context, categoria);
                        },
                      ),
                    ),
                  ],
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
                        return _construirListaProductos(productos, categorias, pageIndex);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // ← ELIMINADO: floatingActionButton
    );
  }

  void _mostrarOpcionesCategoria(BuildContext context, CategoriaModel categoria) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opciones de categoría',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit,),
              title: const Text('Editar categoría'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editarCategoria(context, categoria);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar categoría',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _eliminarCategoria(context, categoria);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesProducto(
      BuildContext context,
      ProductoModel producto,
      List<CategoriaModel> categorias,
      ) {
    final dbHelper = DatabaseHelper();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Precio: \$${_formatearPrecio(producto.precio)}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Ver imagen producto'),
              onTap: () {
                Navigator.pop(sheetContext);
                _verImagenProducto(context, producto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar producto'),
              onTap: () async {
                Navigator.pop(sheetContext);

                final productoActualizado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditarProductoPage(
                      producto: producto,
                      categorias: categorias,
                    ),
                  ),
                );

                if (productoActualizado != null) {
                  try {
                    await dbHelper.actualizarProducto(productoActualizado);
                    ref.invalidate(productosPorCategoriaProvider(productoActualizado.categoriaId));

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Producto ${productoActualizado.nombre} actualizado'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar producto', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _eliminarProducto(context, producto);
              },
            ),
          ],
        ),
      ),
    );
  }
}
