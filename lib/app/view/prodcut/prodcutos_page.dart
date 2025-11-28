import 'dart:io';

import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/prodcut/crear_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/crear_producto_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_prodcuto_page.dart';
import 'package:flutter/material.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<CategoriaModel> categorias = [];
  List<ProductoModel> productos = [];
  String? _categoriasSeleccionadaId;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  void _cargarCategorias() async {
    try {
      final categoriasCargadas = await _dbHelper.obtenerCategorias();
      if (mounted) {
        setState(() {
          categorias = categoriasCargadas;
          if (categorias.isNotEmpty) {
            _categoriasSeleccionadaId = categorias[0].id;
            _cargarProductos(categorias[0].id!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar categorías: $e')),
        );
      }
    }
  }

  void _cargarProductos(String categoriaId) async {
    try {
      final productosCargados = await _dbHelper.obtenerProductosPorCategoria(categoriaId);
      if (mounted) {
        setState(() {
          productos = productosCargados;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $e')),
        );
      }
    }
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
      // Solo mostrar imágenes de Cloudinary
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

  void _crearCategoria() async {
    final nuevaCategoria = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CrearCategoriaPage(),
      ),
    );

    if (nuevaCategoria != null) {
      try {
        await _dbHelper.insertarCategoria(nuevaCategoria);
        _cargarCategorias();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categoría ${nuevaCategoria.nombre} creada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _editarCategoria(CategoriaModel categoria) async {
    final categoriaActualizada = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarCategoriaPage(categoria: categoria),
      ),
    );

    if (categoriaActualizada != null) {
      try {
        await _dbHelper.actualizarCategoria(categoriaActualizada);
        _cargarCategorias();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categoría ${categoriaActualizada.nombre} actualizada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _eliminarCategoria(CategoriaModel categoria) {
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
                await _dbHelper.eliminarCategoria(categoria.id!);
                _cargarCategorias();
                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Categoría ${categoria.nombre} eliminada')),
                  );
                }
              } catch (e) {
                if (mounted) {
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

  void _crearProducto() async {
    final nuevoProducto = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearProductoPage(categorias: categorias),
      ),
    );

    if (nuevoProducto != null) {
      try {
        await _dbHelper.insertarProducto(nuevoProducto);
        _cargarProductos(_categoriasSeleccionadaId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto ${nuevoProducto.nombre} creado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _editarProducto(ProductoModel producto) async {
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
        await _dbHelper.actualizarProducto(productoActualizado);
        _cargarProductos(_categoriasSeleccionadaId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto ${productoActualizado.nombre} actualizado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _eliminarProducto(ProductoModel producto) {
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
                await _dbHelper.eliminarProducto(producto.id!);
                _cargarProductos(_categoriasSeleccionadaId!);
                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Producto ${producto.nombre} eliminado')),
                  );
                }
              } catch (e) {
                if (mounted) {
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

  void _mostrarMenuFlotante() {
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
                _crearCategoria();
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_drink),
              title: const Text('Crear Producto'),
              onTap: () {
                Navigator.pop(context);
                _crearProducto();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
      ),
      body: Column(
        children: [
          // Fila de categorías
          if (categorias.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];
                  final isSelected = _categoriasSeleccionadaId == categoria.id;

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
                                  _editarCategoria(categoria);
                                },
                                child: const Text('Editar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _eliminarCategoria(categoria);
                                },
                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
                          setState(() {
                            _categoriasSeleccionadaId = categoria.id;
                            _cargarProductos(categoria.id!);
                          });
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
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: const Text('No hay categorías. Crea una nueva.'),
            ),

          // Contenido principal - Lista de Productos
          Expanded(
            child: productos.isEmpty
                ? const Center(
              child: Text('No hay productos en esta categoría'),
            )
                : ListView.builder(
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
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(producto.nombre),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _editarProducto(producto);
                              },
                              child: const Text('Editar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _eliminarProducto(producto);
                              },
                              child: const Text('Eliminar',
                                  style: TextStyle(color: Colors.red)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarMenuFlotante,
        child: const Icon(Icons.add),
      ),
    );
  }
}