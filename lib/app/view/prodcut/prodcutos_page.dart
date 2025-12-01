import 'dart:io';

import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/prodcut/crear_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/crear_producto_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_prodcuto_page.dart';
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

// Provider para productos por categoría específica (con family)
final productosPorCategoriaProvider = FutureProvider.family<List<ProductoModel>, String>((ref, categoriaId) async {
  final dbHelper = DatabaseHelper();
  return await dbHelper.obtenerProductosPorCategoria(categoriaId);
});

// ============= PÁGINA =============
class ProductosPage extends ConsumerStatefulWidget {
  const ProductosPage({super.key});

  @override
  ConsumerState<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends ConsumerState<ProductosPage> {
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

                // Ajustar el índice si es necesario
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
        // Invalidar el provider específico de la categoría
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

  // void _editarProducto(BuildContext context, ProductoModel producto, List<CategoriaModel> categorias) async {
  //   final dbHelper = DatabaseHelper();
  //   final productoActualizado = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => EditarProductoPage(
  //         producto: producto,
  //         categorias: categorias,
  //       ),
  //     ),
  //   );
  //
  //   if (productoActualizado != null) {
  //     try {
  //       await dbHelper.actualizarProducto(productoActualizado);
  //       // Invalidar ambas categorías por si cambió de categoría
  //       ref.invalidate(productosPorCategoriaProvider(producto.categoriaId));
  //       if (productoActualizado.categoriaId != producto.categoriaId) {
  //         ref.invalidate(productosPorCategoriaProvider(productoActualizado.categoriaId));
  //       }
  //
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Producto ${productoActualizado.nombre} actualizado')),
  //         );
  //       }
  //     } catch (e) {
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Error: $e')),
  //         );
  //       }
  //     }
  //   }
  // }

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Crear Categoría'),
              onTap: () {
                Navigator.pop(context);
                _crearCategoria(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_drink),
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
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _mostrarOpcionesProducto(context, producto, categorias);
            },
            onLongPress: () => _verImagenProducto(context, producto),
          ),
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

          // Ajustar el índice si está fuera de rango
          if (categoriaIndex >= categorias.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(categoriaIndexProvider.notifier).state = 0;
              _pageController.jumpToPage(0);
            });
          }

          return Column(
            children: [
              // Fila de categorías con indicador
              Container(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
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
                            child: GestureDetector(
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(categoria.nombre),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _editarCategoria(context, categoria);
                                        },
                                        child: const Text('Editar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _eliminarCategoria(context, categoria);
                                        },
                                        child: const Text(
                                          'Eliminar',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancelar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // PageView con los productos
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: categorias.length,
                  onPageChanged: (index) {
                    ref.read(categoriaIndexProvider.notifier).state = index;
                  },
                  itemBuilder: (context, pageIndex) {
                    // Obtener la categoría específica para esta página
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
      floatingActionButton: categoriasAsync.maybeWhen(
        data: (categorias) => FloatingActionButton(
          onPressed: () => _mostrarMenuFlotante(context, categorias),
          child: const Icon(Icons.add),
        ),
        orElse: () => null,
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

            // VER IMAGEN PRODUCTO
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Ver imagen producto'),
              onTap: () {
                Navigator.pop(sheetContext);
                _verImagenProducto(context, producto);
              },
            ),

            // EDITAR PRODUCTO
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
            // ELIMINAR PRODUCTO
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