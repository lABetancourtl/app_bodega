import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';

// ============= CACHE MANAGER =============
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Duración del caché en minutos
  static const int cacheDurationMinutes = 5;

  factory CacheManager() {
    return _instance;
  }

  CacheManager._internal();

  // Guardar en caché
  void set(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
    print('💾 Cache guardado: $key');
  }

  // Obtener del caché
  dynamic get(String key) {
    if (_cache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null) {
        final diferencia = DateTime.now().difference(timestamp).inMinutes;
        if (diferencia < cacheDurationMinutes) {
          print('✅ Cache válido: $key (${diferencia}min)');
          return _cache[key];
        } else {
          print('⏰ Cache expirado: $key');
          _cache.remove(key);
          _cacheTimestamps.remove(key);
          return null;
        }
      }
    }
    return null;
  }

  // Limpiar caché específico
  void clear(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    print('🗑️ Cache limpiado: $key');
  }

  // Limpiar todo el caché
  void clearAll() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('🗑️ Todo el caché limpiado');
  }
}

// ============= PROVIDERS =============
final cacheManagerProvider = Provider((ref) => CacheManager());

// ========== CATEGORÍAS ==========
final categoriasProvider = FutureProvider<List<CategoriaModel>>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  final dbHelper = DatabaseHelper();

  // Intentar obtener del caché
  final cached = cacheManager.get('categorias');
  if (cached != null) {
    return cached as List<CategoriaModel>;
  }

  // Si no está en caché, obtener de la BD
  final categorias = await dbHelper.obtenerCategorias();
  cacheManager.set('categorias', categorias);
  return categorias;
});

// ========== CLIENTES ==========
final clientesProvider = FutureProvider<List<ClienteModel>>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  final dbHelper = DatabaseHelper();

  final cached = cacheManager.get('clientes');
  if (cached != null) {
    return cached as List<ClienteModel>;
  }

  final clientes = await dbHelper.obtenerClientes();
  cacheManager.set('clientes', clientes);
  return clientes;
});

// ========== PRODUCTOS ==========
final productosProvider = FutureProvider<List<ProductoModel>>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  final dbHelper = DatabaseHelper();

  final cached = cacheManager.get('productos');
  if (cached != null) {
    return cached as List<ProductoModel>;
  }

  final productos = await dbHelper.obtenerProductos();
  cacheManager.set('productos', productos);
  return productos;
});

// Productos por categoría
final productosPorCategoriaProvider = FutureProvider.family<List<ProductoModel>, String>((ref, categoriaId) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  final dbHelper = DatabaseHelper();

  final cacheKey = 'productos_$categoriaId';
  final cached = cacheManager.get(cacheKey);
  if (cached != null) {
    return cached as List<ProductoModel>;
  }

  final productos = await dbHelper.obtenerProductosPorCategoria(categoriaId);
  cacheManager.set(cacheKey, productos);
  return productos;
});

// ========== FACTURAS ==========
final facturasProvider = FutureProvider<List<FacturaModel>>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  final dbHelper = DatabaseHelper();

  final cached = cacheManager.get('facturas');
  if (cached != null) {
    return cached as List<FacturaModel>;
  }

  final facturas = await dbHelper.obtenerFacturas();
  cacheManager.set('facturas', facturas);
  return facturas;
});

// ============= MÉTODOS PARA INVALIDAR CACHÉ =============
class CacheHelper {
  static void invalidarCategorias(WidgetRef ref) {
    final cacheManager = ref.read(cacheManagerProvider);
    cacheManager.clear('categorias');
    ref.refresh(categoriasProvider);
  }

  static void invalidarClientes(WidgetRef ref) {
    final cacheManager = ref.read(cacheManagerProvider);
    cacheManager.clear('clientes');
    ref.refresh(clientesProvider);
  }

  static void invalidarProductos(WidgetRef ref) {
    final cacheManager = ref.read(cacheManagerProvider);
    cacheManager.clearAll(); // Limpia también productos por categoría
    ref.refresh(productosProvider);
  }

  static void invalidarFacturas(WidgetRef ref) {
    final cacheManager = ref.read(cacheManagerProvider);
    cacheManager.clear('facturas');
    ref.refresh(facturasProvider);
  }

  static void invalidarTodo(WidgetRef ref) {
    final cacheManager = ref.read(cacheManagerProvider);
    cacheManager.clearAll();
    ref.refresh(categoriasProvider);
    ref.refresh(clientesProvider);
    ref.refresh(productosProvider);
    ref.refresh(facturasProvider);
  }

}