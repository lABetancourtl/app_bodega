import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/categoria_model.dart';
import '../model/cliente_model.dart';
import '../model/prodcuto_model.dart';

class CacheService {
  static const String _keyProductos = 'cache_productos';
  static const String _keyCategorias = 'cache_categorias';
  static const String _keyClientes = 'cache_clientes';
  static const String _keyTimestamp = 'cache_timestamp_';

  // Duración del caché en horas
  static const int cacheDurationHours = 24;

  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // ============= PRODUCTOS =============
  static Future<void> guardarProductos(List<ProductoModel> productos) async {
    try {
      final prefs = await _getPrefs();

      // ✅ Verificar que todos tengan ID antes de guardar
      int sinId = 0;
      for (var producto in productos) {
        if (producto.id == null) {
          sinId++;
          print('⚠️ Producto sin ID: ${producto.nombre}');
        }
      }

      if (sinId > 0) {
        print('❌ No se puede guardar caché: $sinId productos sin ID');
        return;
      }

      // ✅ Usar toJson() que incluye el ID
      final jsonList = productos.map((p) => p.toJson()).toList();
      await prefs.setString(_keyProductos, jsonEncode(jsonList));
      await prefs.setInt('$_keyTimestamp$_keyProductos', DateTime.now().millisecondsSinceEpoch);
      print('💾 ${productos.length} productos guardados en caché');
    } catch (e) {
      print('❌ Error al guardar productos: $e');
    }
  }

  static Future<List<ProductoModel>?> obtenerProductos() async {
    try {
      final prefs = await _getPrefs();

      // Verificar si el caché ha expirado
      final timestamp = prefs.getInt('$_keyTimestamp$_keyProductos');
      if (timestamp != null) {
        final diferencia = DateTime.now().millisecondsSinceEpoch - timestamp;
        final horas = diferencia / (1000 * 60 * 60);

        if (horas > cacheDurationHours) {
          print('⏰ Caché de productos expirado');
          return null;
        }
      }

      final jsonString = prefs.getString(_keyProductos);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);

        // ✅ Usar fromJson() que maneja el ID internamente
        final productos = jsonList
            .map((json) => ProductoModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ ${productos.length} productos cargados desde caché');

        // ✅ Verificar que todos tengan ID
        int sinId = 0;
        for (var producto in productos) {
          if (producto.id == null) {
            sinId++;
            print('⚠️ Producto sin ID cargado: ${producto.nombre}');
          }
        }

        if (sinId > 0) {
          print('❌ Caché corrupto: $sinId productos sin ID. Invalidando...');
          await prefs.remove(_keyProductos);
          await prefs.remove('$_keyTimestamp$_keyProductos');
          return null;
        }

        return productos;
      }
    } catch (e, stack) {
      print('❌ Error al obtener productos del caché: $e');
      print('Stack trace: $stack');
    }
    return null;
  }

  // ============= CATEGORÍAS =============
  static Future<void> guardarCategorias(List<CategoriaModel> categorias) async {
    try {
      final prefs = await _getPrefs();

      // ✅ Verificar que todas tengan ID antes de guardar
      int sinId = 0;
      for (var cat in categorias) {
        if (cat.id == null) {
          sinId++;
          print('⚠️ Categoría sin ID: ${cat.nombre}');
        }
      }

      if (sinId > 0) {
        print('❌ No se puede guardar caché: $sinId categorías sin ID');
        return;
      }

      // ✅ Usar toJson() que incluye el ID, no toMap()
      final jsonList = categorias.map((c) => c.toJson()).toList();
      await prefs.setString(_keyCategorias, jsonEncode(jsonList));
      await prefs.setInt('$_keyTimestamp$_keyCategorias', DateTime.now().millisecondsSinceEpoch);
      print('💾 ${categorias.length} categorías guardadas en caché');

      // ✅ DEBUG: Verificar lo que se guardó
      print('🔍 Verificando datos guardados:');
      for (var i = 0; i < categorias.length && i < 3; i++) {
        print('  - ${categorias[i].nombre}: ID = ${categorias[i].id}');
      }
    } catch (e) {
      print('❌ Error al guardar categorías: $e');
    }
  }

  static Future<List<CategoriaModel>?> obtenerCategorias() async {
    try {
      final prefs = await _getPrefs();

      final timestamp = prefs.getInt('$_keyTimestamp$_keyCategorias');
      if (timestamp != null) {
        final diferencia = DateTime.now().millisecondsSinceEpoch - timestamp;
        final horas = diferencia / (1000 * 60 * 60);

        if (horas > cacheDurationHours) {
          print('⏰ Caché de categorías expirado');
          return null;
        }
      }

      final jsonString = prefs.getString(_keyCategorias);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);

        // ✅ FIX: Asegurarse de que el ID esté en el mapa antes de crear el objeto
        final categorias = jsonList.map((json) {
          // El ID ya debería estar en el JSON
          return CategoriaModel.fromMap(json as Map<String, dynamic>);
        }).toList();

        print('✅ ${categorias.length} categorías cargadas desde caché');

        // ✅ Verificar que todas tengan ID
        int sinId = 0;
        for (var cat in categorias) {
          if (cat.id == null) {
            sinId++;
            print('⚠️ Categoría sin ID cargada: ${cat.nombre}');
          } else {
            print('✓ ${cat.nombre}: ID = ${cat.id}');
          }
        }

        if (sinId > 0) {
          print('❌ Caché corrupto: $sinId categorías sin ID. Invalidando...');
          await prefs.remove(_keyCategorias);
          await prefs.remove('$_keyTimestamp$_keyCategorias');
          return null;
        }

        return categorias;
      }
    } catch (e) {
      print('❌ Error al obtener categorías del caché: $e');
      print('Stack trace: ${StackTrace.current}');
    }
    return null;
  }

  // ============= CLIENTES =============
  static Future<void> guardarClientes(List<ClienteModel> clientes) async {
    try {
      final prefs = await _getPrefs();

      // ✅ Verificar que todos tengan ID antes de guardar
      int sinId = 0;
      for (var cliente in clientes) {
        if (cliente.id == null) {
          sinId++;
          print('⚠️ Cliente sin ID: ${cliente.nombre}');
        }
      }

      if (sinId > 0) {
        print('❌ No se puede guardar caché: $sinId clientes sin ID');
        return;
      }

      // ✅ Usar toJson() que incluye el ID
      final jsonList = clientes.map((c) => c.toJson()).toList();
      await prefs.setString(_keyClientes, jsonEncode(jsonList));
      await prefs.setInt('$_keyTimestamp$_keyClientes', DateTime.now().millisecondsSinceEpoch);
      print('💾 ${clientes.length} clientes guardados en caché');
    } catch (e) {
      print('❌ Error al guardar clientes: $e');
    }
  }

  static Future<List<ClienteModel>?> obtenerClientes() async {
    try {
      final prefs = await _getPrefs();

      final timestamp = prefs.getInt('$_keyTimestamp$_keyClientes');
      if (timestamp != null) {
        final diferencia = DateTime.now().millisecondsSinceEpoch - timestamp;
        final horas = diferencia / (1000 * 60 * 60);

        if (horas > cacheDurationHours) {
          print('⏰ Caché de clientes expirado');
          return null;
        }
      }

      final jsonString = prefs.getString(_keyClientes);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);

        // ✅ Usar fromJson() que maneja el ID internamente
        final clientes = jsonList
            .map((json) => ClienteModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ ${clientes.length} clientes cargados desde caché');

        // ✅ Verificar que todos tengan ID
        int sinId = 0;
        for (var cliente in clientes) {
          if (cliente.id == null) {
            sinId++;
            print('⚠️ Cliente sin ID cargado: ${cliente.nombre}');
          }
        }

        if (sinId > 0) {
          print('❌ Caché corrupto: $sinId clientes sin ID. Invalidando...');
          await prefs.remove(_keyClientes);
          await prefs.remove('$_keyTimestamp$_keyClientes');
          return null;
        }

        return clientes;
      }
    } catch (e, stack) {
      print('❌ Error al obtener clientes del caché: $e');
      print('Stack trace: $stack');
    }
    return null;
  }

  // ============= LIMPIAR CACHÉ =============
  static Future<void> limpiarCache() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyProductos);
    await prefs.remove(_keyCategorias);
    await prefs.remove(_keyClientes);
    await prefs.remove('$_keyTimestamp$_keyProductos');
    await prefs.remove('$_keyTimestamp$_keyCategorias');
    await prefs.remove('$_keyTimestamp$_keyClientes');
    print('🗑️ Caché limpiado completamente');
  }

  // ============= FORZAR ACTUALIZACIÓN =============
  static Future<void> marcarComoDesactualizado(String tipo) async {
    final prefs = await _getPrefs();
    final key = tipo == 'productos' ? _keyProductos
        : tipo == 'categorias' ? _keyCategorias
        : _keyClientes;
    await prefs.remove('$_keyTimestamp$key');
    print('🔄 Caché de $tipo marcado como desactualizado');
  }

  // ============= DIAGNÓSTICO =============
  static Future<void> diagnosticarCache() async {
    try {
      final prefs = await _getPrefs();

      print('🔍 ==========================================');
      print('🔍 DIAGNÓSTICO DE CACHÉ');
      print('🔍 ==========================================');

      // Categorías
      final categoriasJson = prefs.getString(_keyCategorias);
      if (categoriasJson != null) {
        final List<dynamic> jsonList = jsonDecode(categoriasJson);
        print('📦 CATEGORÍAS EN CACHÉ: ${jsonList.length}');
        for (var json in jsonList) {
          print('  - ${json['nombre']}: ID = ${json['id'] ?? "NULL"}');
        }
      } else {
        print('📦 CATEGORÍAS: NO HAY CACHÉ');
      }

      print('🔍 ==========================================');
    } catch (e) {
      print('❌ Error en diagnóstico: $e');
    }
  }
}