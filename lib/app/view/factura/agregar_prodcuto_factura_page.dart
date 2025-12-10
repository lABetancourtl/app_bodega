import 'dart:io';
import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/service/cache_manager.dart';
import 'package:app_bodega/app/view/factura/carrito_productos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../barcode/barcode_scaner_page.dart';

// ============= COLORES DEL TEMA =============
class AppColors {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2E5077);
  static const Color accent = Color(0xFF00B894);
  static const Color accentLight = Color(0xFFE8F8F5);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

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

final carritoTemporalProvider = StateProvider<List<ItemFacturaModel>>((ref) => []);
final productoResaltadoProvider = StateProvider<String?>((ref) => null);
final productoIndexScrollProvider = StateProvider<int?>((ref) => null);

// ============= PÁGINA =============
class AgregarProductoFacturaPage extends ConsumerStatefulWidget {
  final List<ItemFacturaModel>? itemsIniciales;

  const AgregarProductoFacturaPage({super.key, this.itemsIniciales});

  @override
  ConsumerState<AgregarProductoFacturaPage> createState() => _AgregarProductoFacturaPageState();
}

class _AgregarProductoFacturaPageState extends ConsumerState<AgregarProductoFacturaPage> {
  late PageController _pageController;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.itemsIniciales != null && widget.itemsIniciales!.isNotEmpty) {
        ref.read(carritoTemporalProvider.notifier).state = List<ItemFacturaModel>.from(widget.itemsIniciales!);
      } else {
        ref.read(carritoTemporalProvider.notifier).state = [];
      }
    });
  }

  @override
  void dispose() {
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

  void _finalizarSeleccion() {
    final carrito = ref.read(carritoTemporalProvider);
    if (carrito.isEmpty) {
      _mostrarSnackBar('No has agregado ningún producto', isError: true);
      return;
    }
    Navigator.pop(context, carrito);
  }

  void _mostrarCarrito() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CarritoProductosPage()),
    ).then((resultado) {
      if (resultado != null) {
        Navigator.pop(context, resultado);
      }
    });
  }

  void _mostrarSelectorCategorias(List<CategoriaModel> categorias) {
    final currentIndex = ref.read(categoriaIndexProvider);

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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text('${categorias.length} categorías', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  final isSelected = index == currentIndex;

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
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    )
                        : const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ref.read(categoriaIndexProvider.notifier).state = index;
                      _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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

  Widget _buildCategorySelector(List<CategoriaModel> categorias) {
    final currentIndex = ref.watch(categoriaIndexProvider);
    final currentCategory = categorias.isNotEmpty && currentIndex < categorias.length ? categorias[currentIndex] : null;

    return GestureDetector(
      onTap: () => _mostrarSelectorCategorias(categorias),
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
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(
                  currentCategory?.nombre.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                currentCategory?.nombre ?? 'Categoría',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
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

  Widget _buildPageIndicator(int totalPages, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${currentPage + 1}/$totalPages', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
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

  Future<void> _escanearCodigoBarras() async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );

    if (resultado != null && resultado.isNotEmpty) {
      _buscarProductoPorCodigoBarras(resultado);
    }
  }

  Future<void> _buscarProductoPorCodigoBarras(String codigoBarras) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Buscando...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );

    try {
      final dbHelper = DatabaseHelper();
      final producto = await dbHelper.obtenerProductoPorCodigoBarras(codigoBarras);

      Navigator.pop(context);

      if (producto != null) {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 100, 50, 100], intensities: [0, 200, 0, 255]);
        }
        final categoriasAsync = ref.read(categoriasProvider);

        categoriasAsync.whenData((categorias) async {
          final indexCategoria = categorias.indexWhere((cat) => cat.id == producto.categoriaId);

          if (indexCategoria != -1) {
            ref.read(categoriaIndexProvider.notifier).state = indexCategoria;
            _pageController.animateToPage(indexCategoria, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

            final productosEnCategoria = await dbHelper.obtenerProductosPorCategoria(producto.categoriaId);
            final productoIndex = productosEnCategoria.indexWhere((p) => p.id == producto.id);
            if (productoIndex != -1) {
              ref.read(productoIndexScrollProvider.notifier).state = productoIndex;
            }

            ref.read(productoResaltadoProvider.notifier).state = producto.id;

            Future.delayed(const Duration(milliseconds: 2500), () {
              if (mounted) {
                ref.read(productoResaltadoProvider.notifier).state = null;
              }
            });

            _mostrarSnackBar('Producto encontrado: ${producto.nombre}', isSuccess: true);
          }
        });
      } else {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 300, 100, 300], intensities: [0, 128, 0, 128]);
        }
        _mostrarSnackBar('No se encontró producto con código: $codigoBarras', isError: true);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarSnackBar('Error al buscar producto: $e', isError: true);
    }
  }

  Widget _construirListaProductos(List<ProductoModel> productos, List<CategoriaModel> categorias, int categoriaIndex) {
    if (productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            const Text('Sin productos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Esta categoría está vacía', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final scrollController = _getScrollController(categoriaIndex);
    final productoResaltado = ref.watch(productoResaltadoProvider);
    final productoIndexScroll = ref.watch(productoIndexScrollProvider);

    if (productoResaltado != null && productoIndexScroll != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        const double itemHeight = 100.0;
        final double scrollPosition = productoIndexScroll * itemHeight;

        if (scrollController.hasClients) {
          scrollController.animateTo(scrollPosition, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        }

        ref.read(productoIndexScrollProvider.notifier).state = null;
      });
    }

    final carrito = ref.watch(carritoTemporalProvider);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];

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
        final estaResaltado = productoResaltado == producto.id;

        return _ProductoCard(
          producto: producto,
          estaEnCarrito: estaEnCarrito,
          itemEnCarrito: estaEnCarrito ? itemEnCarrito : null,
          estaResaltado: estaResaltado,
          onSelected: (item) {
            final carritoActual = ref.read(carritoTemporalProvider);
            final indexExistente = carritoActual.indexWhere((elemento) => elemento.productoId == item.productoId);

            if (indexExistente != -1) {
              final nuevoCarrito = List<ItemFacturaModel>.from(carritoActual);
              nuevoCarrito[indexExistente] = item;
              ref.read(carritoTemporalProvider.notifier).state = nuevoCarrito;
            } else {
              ref.read(carritoTemporalProvider.notifier).state = List.from(carritoActual)..add(item);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: categoriasAsync.when(
          loading: () => const Text('Cargando...', style: TextStyle(color: AppColors.textSecondary)),
          error: (_, __) => const Text('Error'),
          data: (categorias) => _buildCategorySelector(categorias),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            tooltip: 'Escanear código',
            onPressed: _escanearCodigoBarras,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: AppColors.textPrimary),
                onPressed: _mostrarCarrito,
              ),
              if (carrito.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${carrito.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: categoriasAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Cargando categorías...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $err', style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        data: (categorias) {
          if (categorias.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: AppColors.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('No hay categorías disponibles', style: TextStyle(color: AppColors.textSecondary)),
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
              // Indicador de página
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                ),
                child: _buildPageIndicator(categorias.length, categoriaIndex),
              ),
              // PageView
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
                      loading: () => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text('Cargando productos...', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text('Error: $err', style: const TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                      data: (productos) => _construirListaProductos(productos, categorias, pageIndex),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: carrito.isNotEmpty
          ? Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: _finalizarSeleccion,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Agregar ${carrito.length} ${carrito.length == 1 ? "producto" : "productos"}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }
}

// ============= WIDGET DE TARJETA DE PRODUCTO =============
class _ProductoCard extends StatelessWidget {
  final ProductoModel producto;
  final Function(ItemFacturaModel) onSelected;
  final bool estaEnCarrito;
  final ItemFacturaModel? itemEnCarrito;
  final bool estaResaltado;

  const _ProductoCard({
    required this.producto,
    required this.onSelected,
    this.estaEnCarrito = false,
    this.itemEnCarrito,
    this.estaResaltado = false,
  });

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  Widget _construirImagenProducto(String? imagenPath, {double size = 56}) {
    if (imagenPath != null && imagenPath.isNotEmpty) {
      if (imagenPath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imagenPath,
            fit: BoxFit.cover,
            width: size,
            height: size,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _imagenPlaceholder(size);
            },
            errorBuilder: (context, error, stackTrace) => _imagenPorDefecto(size),
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
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12)),
      child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
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

  void _mostrarDialogoAgregar(BuildContext context) {
    final TextEditingController cantidadTotalController = TextEditingController(text: '0');
    final Map<String, TextEditingController> controllersPorSabor = {};
    final Map<String, int> cantidadPorSabor = {};

    for (var sabor in producto.sabores) {
      controllersPorSabor[sabor] = TextEditingController(text: '0');
      cantidadPorSabor[sabor] = 0;
    }

    int calcularTotal() {
      return cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        _construirImagenProducto(producto.imagenPath, size: 56),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
                              Text('\$${_formatearPrecio(producto.precio)} c/u', style: const TextStyle(fontSize: 14, color: AppColors.accent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
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
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              prefixIcon: const Icon(Icons.inventory, color: AppColors.primary),
                            ),
                            onTap: () {
                              if (cantidadTotalController.text == '0') cantidadTotalController.clear();
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (producto.sabores.length > 1) ...[
                          const Text('Distribuir por sabor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          ...producto.sabores.map((sabor) {
                            final controller = controllersPorSabor[sabor]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(child: Text(sabor, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                      ),
                                      onTap: () {
                                        if (controller.text == '0') controller.clear();
                                      },
                                      onChanged: (value) {
                                        cantidadPorSabor[sabor] = int.tryParse(value) ?? 0;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.sabores.length == 1
                                        ? '${int.tryParse(cantidadTotalController.text) ?? 0} unidades'
                                        : '${calcularTotal()} unidades',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                ],
                              ),
                              Text(
                                producto.sabores.length == 1
                                    ? '\$${_formatearPrecio((int.tryParse(cantidadTotalController.text) ?? 0) * producto.precio)}'
                                    : '\$${_formatearPrecio(calcularTotal() * producto.precio)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              int cantidadTotal;
                              if (producto.sabores.length == 1) {
                                cantidadTotal = int.tryParse(cantidadTotalController.text) ?? 0;
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
                              final nuevoItem = ItemFacturaModel(
                                productoId: producto.id!,
                                nombreProducto: producto.nombre,
                                precioUnitario: producto.precio,
                                cantidadTotal: cantidadTotal,
                                cantidadPorSabor: producto.sabores.length > 1 ? cantidadPorSabor : {producto.sabores[0]: cantidadTotal},
                                tieneSabores: producto.sabores.length > 1,
                              );
                              onSelected(nuevoItem);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      const SizedBox(width: 12),
                                      Text('${producto.nombre} agregado'),
                                    ],
                                  ),
                                  backgroundColor: AppColors.accent,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(milliseconds: 1500),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          onTap: () => _mostrarDialogoAgregar(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: estaEnCarrito ? AppColors.accent : (estaResaltado ? AppColors.accent : AppColors.border),
                width: estaEnCarrito || estaResaltado ? 2 : 1,
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                          ),
                          if (estaEnCarrito && itemEnCarrito != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                '${itemEnCarrito!.cantidadTotal} uds',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: estaEnCarrito ? AppColors.accent : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    estaEnCarrito ? Icons.check : Icons.add,
                    color: estaEnCarrito ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}