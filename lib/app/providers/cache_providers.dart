import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../datasources/database_helper.dart';
import '../model/categoria_model.dart';
import '../model/cliente_model.dart';
import '../model/prodcuto_model.dart';
import '../service/cache_service.dart';

// ============= PROVIDER DE CONECTIVIDAD =============
final conectividadProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged.map((results) => results.first);
});

// ============= CATEGORÍAS CON CACHÉ =============
final categoriasProvider = FutureProvider<List<CategoriaModel>>((ref) async {
  final dbHelper = DatabaseHelper();

  // 1. Intentar cargar desde caché primero
  final cacheCategorias = await CacheService.obtenerCategorias();
  if (cacheCategorias != null && cacheCategorias.isNotEmpty) {
    // Sincronizar en segundo plano
    _sincronizarCategorias(dbHelper);
    return cacheCategorias;
  }

  // 2. Si no hay caché, cargar desde BD
  print('🌐 Cargando categorías desde Firebase...');
  final categorias = await dbHelper.obtenerCategorias();

  // 3. Guardar en caché
  await CacheService.guardarCategorias(categorias);

  return categorias;
});

Future<void> _sincronizarCategorias(DatabaseHelper dbHelper) async {
  try {
    final categorias = await dbHelper.obtenerCategorias();
    await CacheService.guardarCategorias(categorias);
    print('🔄 Categorías sincronizadas en segundo plano');
  } catch (e) {
    print('⚠️ Error en sincronización de categorías: $e');
  }
}

// ============= PRODUCTOS CON CACHÉ =============
final productosProvider = FutureProvider<List<ProductoModel>>((ref) async {
  final dbHelper = DatabaseHelper();

  // 1. Intentar cargar desde caché primero
  final cacheProductos = await CacheService.obtenerProductos();
  if (cacheProductos != null && cacheProductos.isNotEmpty) {
    // Sincronizar en segundo plano
    _sincronizarProductos(dbHelper);
    return cacheProductos;
  }

  // 2. Si no hay caché, cargar desde BD
  print('🌐 Cargando productos desde Firebase...');
  final productos = await dbHelper.obtenerProductos();

  // 3. Guardar en caché
  await CacheService.guardarProductos(productos);

  return productos;
});

Future<void> _sincronizarProductos(DatabaseHelper dbHelper) async {
  try {
    final productos = await dbHelper.obtenerProductos();
    await CacheService.guardarProductos(productos);
    print('🔄 Productos sincronizados en segundo plano');
  } catch (e) {
    print('⚠️ Error en sincronización de productos: $e');
  }
}

// ============= PRODUCTOS POR CATEGORÍA =============
final productosPorCategoriaProvider = FutureProvider.family<List<ProductoModel>, String>((ref, categoriaId) async {
  // Obtener todos los productos del caché
  final todosLosProductos = await ref.watch(productosProvider.future);

  // Filtrar por categoría en memoria
  return todosLosProductos.where((p) => p.categoriaId == categoriaId).toList();
});

// ============= CLIENTES CON CACHÉ =============
final clientesProvider = FutureProvider<List<ClienteModel>>((ref) async {
  final dbHelper = DatabaseHelper();

  // 1. Intentar cargar desde caché primero
  final cacheClientes = await CacheService.obtenerClientes();
  if (cacheClientes != null && cacheClientes.isNotEmpty) {
    // Sincronizar en segundo plano
    _sincronizarClientes(dbHelper);
    return cacheClientes;
  }

  // 2. Si no hay caché, cargar desde BD
  print('🌐 Cargando clientes desde Firebase...');
  final clientes = await dbHelper.obtenerClientes();

  // 3. Guardar en caché
  await CacheService.guardarClientes(clientes);

  return clientes;
});

Future<void> _sincronizarClientes(DatabaseHelper dbHelper) async {
  try {
    final clientes = await dbHelper.obtenerClientes();
    await CacheService.guardarClientes(clientes);
    print('🔄 Clientes sincronizados en segundo plano');
  } catch (e) {
    print('⚠️ Error en sincronización de clientes: $e');
  }
}

// ============= HELPER PARA INVALIDAR CACHÉ =============
class CacheHelper {
  static Future<void> invalidarProductos(WidgetRef ref) async {
    await CacheService.marcarComoDesactualizado('productos');
    ref.invalidate(productosProvider);
  }

  static Future<void> invalidarCategorias(WidgetRef ref) async {
    await CacheService.marcarComoDesactualizado('categorias');
    ref.invalidate(categoriasProvider);
  }

  static Future<void> invalidarClientes(WidgetRef ref) async {
    await CacheService.marcarComoDesactualizado('clientes');
    ref.invalidate(clientesProvider);
  }

  static Future<void> invalidarTodo(WidgetRef ref) async {
    await CacheService.limpiarCache();
    ref.invalidate(productosProvider);
    ref.invalidate(categoriasProvider);
    ref.invalidate(clientesProvider);
  }
}