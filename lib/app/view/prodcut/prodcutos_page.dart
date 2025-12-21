import 'dart:io';

import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/view/prodcut/crear_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/crear_producto_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_categoria_page.dart';
import 'package:app_bodega/app/view/prodcut/editar_prodcuto_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../../providers/cache_providers.dart';
import '../../service/catalogo_pdf_service.dart';
import '../../widgets/imagen_viewer_widget.dart';
import '../barcode/barcode_scaner_page.dart' as scanner;
import 'package:app_bodega/app/theme/app_colors.dart';

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

final productoResaltadoProvider = StateProvider<String?>((ref) => null);
final productoIndexScrollProvider = StateProvider<int?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// ============= PÁGINA PRINCIPAL =============
class ProductosPage extends ConsumerStatefulWidget {
  const ProductosPage({super.key});

  @override
  ConsumerState<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends ConsumerState<ProductosPage> with TickerProviderStateMixin {
  late PageController _pageController;
  final Map<int, ScrollController> _scrollControllers = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _vistaGrid = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoriasAsync = ref.read(categoriasProvider);
      categoriasAsync.whenData((categorias) {
        final currentIndex = ref.read(categoriaIndexProvider);
        if (currentIndex >= categorias.length && categorias.isNotEmpty) {
          ref.read(categoriaIndexProvider.notifier).state = 0;
        }
      });
    });

    final initialIndex = ref.read(categoriaIndexProvider);
    _pageController = PageController(initialPage: initialIndex.clamp(0, 999));
  }

  ScrollController _getScrollController(int index) {
    if (!_scrollControllers.containsKey(index)) {
      _scrollControllers[index] = ScrollController();
    }
    return _scrollControllers[index]!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
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

  Future<void> _generarCatalogoPDF(List<CategoriaModel> categorias) async {
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Generando catálogo PDF...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Esto puede tardar unos segundos',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final dbHelper = DatabaseHelper();

      // Cargar todos los productos por categoría
      Map<String, List<ProductoModel>> productosPorCategoria = {};

      for (var categoria in categorias) {
        final productos = await dbHelper.obtenerProductosPorCategoria(categoria.id!);
        productosPorCategoria[categoria.id!] = productos;
      }

      // Generar PDF
      final pdfFile = await CatalogoPdfService.generarCatalogoPDF(
        categorias: categorias,
        productosPorCategoria: productosPorCategoria,
        nombreNegocio: 'Mi Bodega', // Puedes parametrizar esto
        telefonoContacto: null, // Agrega tu número si lo deseas
      );

      // Cerrar diálogo de carga
      Navigator.pop(context);

      // Mostrar opciones
      _mostrarOpcionesPDF(pdfFile);
    } catch (e) {
      // Cerrar diálogo de carga
      Navigator.pop(context);

      _mostrarSnackBar('Error al generar PDF: $e', isError: true);
    }
  }

  void _mostrarOpcionesPDF(File pdfFile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF Generado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Catálogo de productos',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.share,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: const Text('Compartir PDF'),
              subtitle: const Text('Enviar por WhatsApp, email, etc.'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await CatalogoPdfService.compartirPDF(pdfFile);
                  _mostrarSnackBar('Compartiendo catálogo...', isSuccess: true);
                } catch (e) {
                  _mostrarSnackBar('Error al compartir: $e', isError: true);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.visibility,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              title: const Text('Ver PDF'),
              subtitle: Text(
                'Ubicación: ${pdfFile.path.split('/').last}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () {
                Navigator.pop(context);
                _mostrarSnackBar('PDF guardado en: ${pdfFile.path}');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Mostrar dropdown de categorías
  void _mostrarSelectorCategorias(BuildContext context, List<CategoriaModel> categorias) {
    final currentIndex = ref.read(categoriaIndexProvider);

    // FIX: Asegurar que el índice sea válido
    final safeCurrentIndex = currentIndex.clamp(0,
        categorias.isEmpty ? 0 : categorias.length - 1
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.category, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Seleccionar Categoría',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${categorias.length} categorías',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];
                  final isSelected = index == safeCurrentIndex;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: AppColors.accent, width: 2) : null,
                      ),
                      child: Center(
                        child: Text(
                          categoria.nombre.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.accent : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      categoria.nombre,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.accent : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    )
                        : const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _navegarACategoria(index);
                    },
                    onLongPress: () {
                      Navigator.pop(sheetContext);
                      _mostrarOpcionesCategoria(context, categoria);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navegarACategoria(int index) {
    ref.read(categoriaIndexProvider.notifier).state = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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

  void _buscarProductoPorCodigoBarras(String codigoBarras, List<CategoriaModel> categorias) async {
    final dbHelper = DatabaseHelper();

    try {
      final producto = await dbHelper.obtenerProductoPorCodigoBarras(codigoBarras);

      if (producto != null) {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 100, 50, 100], intensities: [0, 200, 0, 255]);
        }

        final categoriaIndex = categorias.indexWhere((cat) => cat.id == producto.categoriaId);

        if (categoriaIndex != -1) {
          _navegarACategoria(categoriaIndex);

          ref.read(productoResaltadoProvider.notifier).state = producto.id;

          final productosEnCategoria = await dbHelper.obtenerProductosPorCategoria(producto.categoriaId);
          final productoIndex = productosEnCategoria.indexWhere((p) => p.id == producto.id);
          if (productoIndex != -1) {
            ref.read(productoIndexScrollProvider.notifier).state = productoIndex;
          }

          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) {
              ref.read(productoResaltadoProvider.notifier).state = null;
            }
          });

          if (mounted) {
            _mostrarSnackBar('Producto encontrado: ${producto.nombre}', isSuccess: true);
          }
        }
      } else {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 300, 100, 300], intensities: [0, 128, 0, 128]);
        }
        if (mounted) {
          _mostrarSnackBar('No se encontró producto con código: $codigoBarras', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error al buscar producto: $e', isError: true);
      }
    }
  }

  void _mostrarSnackBar(String mensaje, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : (isError ? Icons.error : Icons.info),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.accent : (isError ? AppColors.error : AppColors.primary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Widget _construirImagenProducto(String? imagenPath, {double size = 56}) {
    if (imagenPath != null && imagenPath.isNotEmpty) {
      if (imagenPath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imagenPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => _imagenPlaceholder(size),
            errorWidget: (context, url, error) => _imagenPorDefecto(size),
            memCacheWidth: (size * 2).toInt(), // Optimizar memoria
            memCacheHeight: (size * 2).toInt(),
          ),
        );
      } else {
        final file = File(imagenPath);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, fit: BoxFit.cover, width: size, height: size),
          );
        }
      }
    }
    return _imagenPorDefecto(size);
  }

  Widget _imagenPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _imagenPorDefecto(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.1), AppColors.accent.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.inventory_2_outlined, size: size * 0.4, color: AppColors.primary),
    );
  }

  void _crearCategoria(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final nuevaCategoria = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CrearCategoriaPage()),
    );

    if (nuevaCategoria != null) {
      try {
        await dbHelper.insertarCategoria(nuevaCategoria);

        await CacheHelper.invalidarCategorias(ref);

        if (context.mounted) {
          _mostrarSnackBar('Categoría ${nuevaCategoria.nombre} creada', isSuccess: true);
        }
      } catch (e) {
        if (context.mounted) {
          _mostrarSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  void _editarCategoria(BuildContext context, CategoriaModel categoria) async {
    final dbHelper = DatabaseHelper();
    final categoriaActualizada = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditarCategoriaPage(categoria: categoria)),
    );

    if (categoriaActualizada != null) {
      try {
        await dbHelper.actualizarCategoria(categoriaActualizada);

        await CacheHelper.invalidarCategorias(ref);

        if (context.mounted) {
          _mostrarSnackBar('Categoría ${categoriaActualizada.nombre} actualizada', isSuccess: true);
        }
      } catch (e) {
        if (context.mounted) {
          _mostrarSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  void _eliminarCategoria(BuildContext context, CategoriaModel categoria) {
    final dbHelper = DatabaseHelper();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Categoría'),
          ],
        ),
        content: Text('¿Estás seguro de que deseas eliminar "${categoria.nombre}"?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                await dbHelper.eliminarCategoria(categoria.id!);
                await CacheHelper.invalidarCategorias(ref);

                final currentIndex = ref.read(categoriaIndexProvider);
                if (currentIndex > 0) {
                  ref.read(categoriaIndexProvider.notifier).state = currentIndex - 1;
                }
                Navigator.pop(context);
                if (context.mounted) {
                  _mostrarSnackBar('Categoría eliminada', isSuccess: true);
                }
              } catch (e) {
                Navigator.pop(context);
                if (context.mounted) {
                  _mostrarSnackBar('Error: $e', isError: true);
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _crearProducto(BuildContext context, List<CategoriaModel> categorias) async {
    final dbHelper = DatabaseHelper();
    final nuevoProducto = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CrearProductoPage(categorias: categorias)),
    );

    if (nuevoProducto != null) {
      try {
        await dbHelper.insertarProducto(nuevoProducto);
        await CacheHelper.invalidarProductos(ref);

        if (context.mounted) {
          _mostrarSnackBar('Producto ${nuevoProducto.nombre} creado', isSuccess: true);
        }
      } catch (e) {
        if (context.mounted) {
          _mostrarSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  void _eliminarProducto(BuildContext context, ProductoModel producto) {
    final dbHelper = DatabaseHelper();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Eliminar Producto')),
          ],
        ),
        content: Text('¿Eliminar "${producto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                await dbHelper.eliminarProducto(producto.id!);
                await CacheHelper.invalidarProductos(ref);

                Navigator.pop(context);
                if (context.mounted) {
                  _mostrarSnackBar('Producto eliminado', isSuccess: true);
                }
              } catch (e) {
                Navigator.pop(context);
                if (context.mounted) {
                  _mostrarSnackBar('Error: $e', isError: true);
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verImagenProducto(BuildContext context, ProductoModel producto) {
    if (producto.imagenPath != null && producto.imagenPath!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagenViewerPage(
            imagenPath: producto.imagenPath,
            titulo: producto.nombre,
          ),
        ),
      );
    } else {
      _mostrarSnackBar('Este producto no tiene imagen');
    }
  }

  void _mostrarMenuFlotante(BuildContext context, List<CategoriaModel> categorias) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Opciones',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildMenuOption(
              icon: Icons.picture_as_pdf,
              iconColor: AppColors.primary,
              title: 'Generar Catálogo PDF',
              subtitle: 'Crear PDF con todos los productos',
              onTap: () {
                Navigator.pop(context);
                _generarCatalogoPDF(categorias);
              },
            ),
            _buildMenuOption(
              icon: Icons.category_outlined,
              iconColor: AppColors.primary,
              title: 'Nueva Categoría',
              subtitle: 'Agregar una categoría de productos',
              onTap: () {
                Navigator.pop(context);
                _crearCategoria(context);
              },
            ),
            _buildMenuOption(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.primary,
              title: 'Nuevo Producto',
              subtitle: 'Agregar un producto al catálogo',
              onTap: () {
                Navigator.pop(context);
                _crearProducto(context, categorias);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _mostrarOpcionesCategoria(BuildContext context, CategoriaModel categoria) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.category, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoria.nombre,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Text('Opciones de categoría', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
              ),
              title: const Text('Editar categoría'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editarCategoria(context, categoria);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              ),
              title: const Text('Eliminar categoría', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _eliminarCategoria(context, categoria);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesProducto(BuildContext context, ProductoModel producto, List<CategoriaModel> categorias) {
    final dbHelper = DatabaseHelper();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _construirImagenProducto(producto.imagenPath, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${_formatearPrecio(producto.precio)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 20),
              ),
              title: const Text('Ver imagen'),
              onTap: () {
                Navigator.pop(sheetContext);
                _verImagenProducto(context, producto);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
              ),
              title: const Text('Editar producto'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final productoActualizado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditarProductoPage(producto: producto, categorias: categorias),
                  ),
                );

                if (productoActualizado != null) {
                  try {
                    await dbHelper.actualizarProducto(productoActualizado);
                    await CacheHelper.invalidarProductos(ref);

                    if (context.mounted) {
                      _mostrarSnackBar('Producto actualizado', isSuccess: true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      _mostrarSnackBar('Error: $e', isError: true);
                    }
                  }
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              ),
              title: const Text('Eliminar producto', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _eliminarProducto(context, producto);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _construirListaProductos(List<ProductoModel> productos, List<CategoriaModel> categorias, int categoriaIndex) {
    if (productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin productos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega productos a esta categoría',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _crearProducto(context, categorias),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Agregar Producto'),
            ),
          ],
        ),
      );
    }

    final scrollController = _getScrollController(categoriaIndex);
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

    final productosFiltrados = searchQuery.isEmpty
        ? productos
        : productos.where((p) =>
    p.nombre.toLowerCase().contains(searchQuery) ||
        p.sabores.any((s) => s.toLowerCase().contains(searchQuery))
    ).toList();

    return Consumer(
      builder: (context, ref, child) {
        final productoResaltado = ref.watch(productoResaltadoProvider);
        final productoIndexScroll = ref.watch(productoIndexScrollProvider);

        if (productoResaltado != null && productoIndexScroll != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final double itemHeight = _vistaGrid ? 260.0 : 88.0;
            final double scrollPosition = productoIndexScroll * itemHeight;

            if (scrollController.hasClients) {
              scrollController.animateTo(
                scrollPosition,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
            ref.read(productoIndexScrollProvider.notifier).state = null;
          });
        }

        if (productosFiltrados.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text('No se encontraron productos', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        // ========== VISTA CARDS (CATÁLOGO) ==========
        if (_vistaGrid) {
          return GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemCount: productosFiltrados.length,
            itemBuilder: (context, index) {
              final producto = productosFiltrados[index];
              final estaResaltado = productoResaltado == producto.id;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _mostrarOpcionesProducto(context, producto, categorias),
                    onLongPress: () => _verImagenProducto(context, producto),
                    child: Container(
                      decoration: BoxDecoration(
                        color: estaResaltado ? AppColors.accentLight : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: estaResaltado ? AppColors.accent : AppColors.border,
                          width: estaResaltado ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: estaResaltado
                                ? AppColors.accent.withOpacity(0.2)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: estaResaltado ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Imagen del producto
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _construirImagenProductoCard(producto.imagenPath),
                            ),
                          ),

                          // Información del producto
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Nombre y sabores
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        producto.nombre,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (producto.sabores.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          producto.sabores.join(' • '),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),

                                  // Precio y cantidad
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '\$${_formatearPrecio(producto.precio)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accent,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (producto.cantidadPorPaca != null) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 9,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${producto.cantidadPorPaca} x paca',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        // ========== VISTA LISTA (PREVENTA - POR DEFECTO) ==========
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: productosFiltrados.length,
          itemBuilder: (context, index) {
            final producto = productosFiltrados[index];
            final estaResaltado = productoResaltado == producto.id;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: estaResaltado ? AppColors.accentLight : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                elevation: estaResaltado ? 4 : 0,
                shadowColor: estaResaltado ? AppColors.accent.withOpacity(0.3) : Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _mostrarOpcionesProducto(context, producto, categorias),
                  onLongPress: () => _verImagenProducto(context, producto),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: estaResaltado ? AppColors.accent : AppColors.border,
                        width: estaResaltado ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _construirImagenProducto(producto.imagenPath),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                producto.nombre,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (producto.sabores.isNotEmpty)
                                Text(
                                  producto.sabores.join(' • '),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '\$${_formatearPrecio(producto.precio)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                  if (producto.cantidadPorPaca != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${producto.cantidadPorPaca} x paca',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirImagenProductoCard(String? imagenPath) {
    if (imagenPath != null && imagenPath.isNotEmpty) {
      if (imagenPath.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: imagenPath,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.border,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
          errorWidget: (context, url, error) => _imagenPorDefectoCard(),
          memCacheWidth: 400,
          memCacheHeight: 400,
        );
      } else {
        final file = File(imagenPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
          );
        }
      }
    }
    return _imagenPorDefectoCard();
  }

  Widget _imagenPorDefectoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.accent.withOpacity(0.1)
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 50,
          color: AppColors.primary.withOpacity(0.4),
        ),
      ),
    );
  }

// // Nuevo método específico para imágenes en cards
//   Widget _construirImagenProductoCard(String? imagenPath) {
//     if (imagenPath != null && imagenPath.isNotEmpty) {
//       if (imagenPath.startsWith('http')) {
//         return CachedNetworkImage(
//           imageUrl: imagenPath,
//           fit: BoxFit.cover,
//           placeholder: (context, url) => Container(
//             color: AppColors.border,
//             child: const Center(
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: AppColors.primary,
//               ),
//             ),
//           ),
//           errorWidget: (context, url, error) => _imagenPorDefectoCard(),
//           memCacheWidth: 400,
//           memCacheHeight: 400,
//         );
//       } else {
//         final file = File(imagenPath);
//         if (file.existsSync()) {
//           return Image.file(
//             file,
//             fit: BoxFit.cover,
//           );
//         }
//       }
//     }
//     return _imagenPorDefectoCard();
//   }
//
//   Widget _imagenPorDefectoCard() {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             AppColors.primary.withOpacity(0.1),
//             AppColors.accent.withOpacity(0.1)
//           ],
//         ),
//       ),
//       child: Center(
//         child: Icon(
//           Icons.inventory_2_outlined,
//           size: 50,
//           color: AppColors.primary.withOpacity(0.4),
//         ),
//       ),
//     );
//   }

  // Widget para el selector de categoría en el header
  Widget _buildCategorySelector(List<CategoriaModel> categorias) {
    final currentIndex = ref.watch(categoriaIndexProvider);

    // FIX: Verificación segura del índice y la categoría
    final currentCategory = (categorias.isNotEmpty &&
        currentIndex >= 0 &&
        currentIndex < categorias.length)
        ? categorias[currentIndex]
        : null;

    return GestureDetector(
      onTap: () => _mostrarSelectorCategorias(context, categorias),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  currentCategory?.nombre.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                currentCategory?.nombre ?? 'Categoría',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // Indicador de página actual
  Widget _buildPageIndicator(int totalPages, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${currentPage + 1}/$totalPages',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(
            totalPages > 5 ? 5 : totalPages,
                (index) {
              int dotIndex = index;
              if (totalPages > 5) {
                if (currentPage < 3) {
                  dotIndex = index;
                } else if (currentPage > totalPages - 3) {
                  dotIndex = totalPages - 5 + index;
                } else {
                  dotIndex = currentPage - 2 + index;
                }
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: dotIndex == currentPage ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotIndex == currentPage ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final currentIndex = ref.watch(categoriaIndexProvider);

    return categoriasAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Cargando catálogo...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $err', style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(categoriasProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (categorias) {
        if (categorias.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: const Text(
                'Productos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.textPrimary),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                  onPressed: () => _mostrarMenuFlotante(context, categorias),
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.category_outlined, size: 80, color: AppColors.primary.withOpacity(0.3)),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Sin categorías',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Comienza creando tu primera categoría',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _crearCategoria(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Categoría', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentIndex >= categorias.length) {
            ref.read(categoriaIndexProvider.notifier).state = 0;
          }
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 1,
            titleSpacing: 16,
            title: _isSearching
                ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar productos...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            )
                : _buildCategorySelector(categorias),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    });
                  },
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.textPrimary),
                  tooltip: 'Buscar',
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    _vistaGrid ? Icons.view_list : Icons.grid_view,
                    color: AppColors.primary,
                  ),
                  tooltip: _vistaGrid ? 'Vista rápida' : 'Vista catálogo',
                  onPressed: () {
                    setState(() {
                      _vistaGrid = !_vistaGrid;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  tooltip: 'Escanear código',
                  onPressed: () => _escanearCodigoBarras(context, categorias),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  tooltip: 'Crear nuevo',
                  onPressed: () => _mostrarMenuFlotante(context, categorias),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                ),
                child: _buildPageIndicator(
                    categorias.length,
                    // FIX: Asegurar que el índice sea válido
                    currentIndex.clamp(0, categorias.length - 1)
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
                    // FIX: Verificar que el índice sea válido
                    if (pageIndex >= categorias.length) {
                      return const Center(
                        child: Text('Índice inválido'),
                      );
                    }

                    final categoria = categorias[pageIndex];

                    // FIX: Verificar que categoria.id no sea null
                    final categoriaId = categoria.id;
                    if (categoriaId == null) {
                      return const Center(
                        child: Text('Categoría sin ID'),
                      );
                    }

                    final productosAsync = ref.watch(
                        productosPorCategoriaProvider(categoriaId)
                    );

                    return productosAsync.when(
                      loading: () => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text('Cargando productos...',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text('Error: $err',
                                style: const TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                      data: (productos) => _construirListaProductos(
                          productos,
                          categorias,
                          pageIndex
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


}

// // ============= PÁGINA PARA VER IMÁGENES =============
// class _ImagenViewerPage extends StatefulWidget {
//   final Widget imageWidget;
//   final String productoNombre;
//
//   const _ImagenViewerPage({
//     required this.imageWidget,
//     required this.productoNombre,
//   });
//
//   @override
//   State<_ImagenViewerPage> createState() => _ImagenViewerPageState();
// }
//
// class _ImagenViewerPageState extends State<_ImagenViewerPage> {
//   final TransformationController _transformationController = TransformationController();
//   TapDownDetails? _doubleTapDetails;
//   bool _showControls = true;
//
//   @override
//   void dispose() {
//     _transformationController.dispose();
//     super.dispose();
//   }
//
//   void _handleDoubleTapDown(TapDownDetails details) {
//     _doubleTapDetails = details;
//   }
//
//   void _handleDoubleTap() {
//     if (_transformationController.value != Matrix4.identity()) {
//       // Si está con zoom, resetear
//       _transformationController.value = Matrix4.identity();
//     } else {
//       // Si está normal, hacer zoom 2.5x en el punto tocado
//       final position = _doubleTapDetails!.localPosition;
//
//       _transformationController.value = Matrix4.identity()
//         ..translate(-position.dx * 1.5, -position.dy * 1.5)
//         ..scale(2.5);
//     }
//   }
//
//   void _toggleControls() {
//     setState(() {
//       _showControls = !_showControls;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // Imagen centrada en toda la pantalla
//           GestureDetector(
//             onTap: _toggleControls,
//             onDoubleTapDown: _handleDoubleTapDown,
//             onDoubleTap: _handleDoubleTap,
//             child: InteractiveViewer(
//               transformationController: _transformationController,
//               minScale: 0.5,
//               maxScale: 4.0,
//               boundaryMargin: const EdgeInsets.all(80),
//               panEnabled: true,
//               scaleEnabled: true,
//               child: SizedBox(
//                 width: MediaQuery.of(context).size.width,
//                 height: MediaQuery.of(context).size.height,
//                 child: Center(
//                   child: widget.imageWidget,
//                 ),
//               ),
//             ),
//           ),
//
//           // AppBar flotante
//           if (_showControls)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 padding: EdgeInsets.only(
//                   top: MediaQuery.of(context).padding.top,
//                 ),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.7),
//                       Colors.black.withOpacity(0.3),
//                       Colors.transparent,
//                     ],
//                   ),
//                 ),
//                 child: SafeArea(
//                   bottom: false,
//                   child: SizedBox(
//                     height: kToolbarHeight,
//                     child: Row(
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.close, color: Colors.white, size: 28),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//                         Expanded(
//                           child: Text(
//                             widget.productoNombre,
//                             style: const TextStyle(
//                               fontSize: 16,
//                               color: Colors.white,
//                               fontWeight: FontWeight.w500,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                         const SizedBox(width: 48), // Balance visual
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }