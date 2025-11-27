import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static const String clientesCol = 'clientes';
  static const String categoriasCol = 'categorias';
  static const String productosCol = 'productos';
  static const String facturasCol = 'facturas';
  static const String itemFacturasCol = 'item_facturas';

// ============= MÉTODOS PARA CLIENTES =============

  Future<String> insertarCliente(ClienteModel cliente) async {
    try {
      final docRef = await _firestore
          .collection(clientesCol)
          .add(cliente.toMap());
      return docRef.id;  // ✅ Retornar String directamente
    } catch (e) {
      throw Exception('Error al insertar cliente: $e');
    }
  }

  Future<List<ClienteModel>> obtenerClientes() async {
    try {
      final snapshot = await _firestore
          .collection(clientesCol)
          .orderBy('nombre')
          .get();

      return snapshot.docs.map((doc) {
        return ClienteModel.fromMap(doc.data(), doc.id);  // ✅ Pasar doc.id
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener clientes: $e');
    }
  }

  Future<ClienteModel?> obtenerClientePorId(String id) async {
    try {
      final doc = await _firestore
          .collection(clientesCol)
          .doc(id)  // ✅ Usar .doc(id) directamente
          .get();

      if (doc.exists) {
        return ClienteModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener cliente: $e');
    }
  }

  Future<void> actualizarCliente(ClienteModel cliente) async {
    try {
      if (cliente.id == null) {
        throw Exception('El cliente debe tener un ID para actualizarse');
      }

      await _firestore
          .collection(clientesCol)
          .doc(cliente.id)  // ✅ Usar el ID directamente
          .update(cliente.toMap());
    } catch (e) {
      throw Exception('Error al actualizar cliente: $e');
    }
  }

  Future<void> eliminarCliente(String id) async {
    try {
      await _firestore
          .collection(clientesCol)
          .doc(id)  // ✅ Usar el ID directamente
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar cliente: $e');
    }
  }

  // ============= MÉTODOS PARA CATEGORÍAS =============

  Future<String> insertarCategoria(CategoriaModel categoria) async {
    try {
      final docRef = await _firestore
          .collection(categoriasCol)
          .add(categoria.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al insertar categoría: $e');
    }
  }

  Future<List<CategoriaModel>> obtenerCategorias() async {
    try {
      final snapshot = await _firestore
          .collection(categoriasCol)
          .orderBy('nombre')
          .get();

      return snapshot.docs.map((doc) {
        return CategoriaModel.fromMap({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener categorías: $e');
    }
  }

  Future<CategoriaModel?> obtenerCategoriaPorId(String id) async {
    try {
      final doc = await _firestore
          .collection(categoriasCol)
          .doc(id)
          .get();

      if (doc.exists) {
        return CategoriaModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener categoría: $e');
    }
  }

  Future<void> actualizarCategoria(CategoriaModel categoria) async {
    try {
      if (categoria.id == null) {
        throw Exception('La categoría debe tener un ID');
      }
      await _firestore
          .collection(categoriasCol)
          .doc(categoria.id)
          .update(categoria.toMap());
    } catch (e) {
      throw Exception('Error al actualizar categoría: $e');
    }
  }

  Future<void> eliminarCategoria(String id) async {
    try {
      await _firestore
          .collection(categoriasCol)
          .doc(id)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar categoría: $e');
    }
  }

  // ============= MÉTODOS PARA PRODUCTOS =============


  Future<String> insertarProducto(ProductoModel producto) async {
    try {
      final docRef = await _firestore
          .collection(productosCol)
          .add(producto.toMap());
      return docRef.id; // ✅ Retornar String directamente
    } catch (e) {
      throw Exception('Error al insertar producto: $e');
    }
  }

  Future<List<ProductoModel>> obtenerProductos() async {
    try {
      final snapshot = await _firestore
          .collection(productosCol)
          .orderBy('nombre')
          .get();

      return snapshot.docs.map((doc) {
        return ProductoModel.fromMap(doc.data(), doc.id); // ✅ Pasar doc.id
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener productos: $e');
    }
  }

  Future<List<ProductoModel>> obtenerProductosPorCategoria(
      String categoriaId) async {
    try {
      final snapshot = await _firestore
          .collection(productosCol)
          .where('categoriaId', isEqualTo: categoriaId)
          .orderBy('nombre')
          .get();

      return snapshot.docs.map((doc) {
        return ProductoModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener productos por categoría: $e');
    }
  }

  Future<ProductoModel?> obtenerProductoPorId(String id) async {
    try {
      final doc = await _firestore
          .collection(productosCol)
          .doc(id) // ✅ Usar .doc(id) directamente
          .get();

      if (doc.exists) {
        return ProductoModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener producto: $e');
    }
  }

  Future<void> actualizarProducto(ProductoModel producto) async {
    try {
      if (producto.id == null) {
        throw Exception('El producto debe tener un ID para actualizarse');
      }

      await _firestore
          .collection(productosCol)
          .doc(producto.id) // ✅ Usar el ID directamente
          .update(producto.toMap());
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  Future<void> eliminarProducto(String id) async {
    try {
      await _firestore
          .collection(productosCol)
          .doc(id) // ✅ Usar el ID directamente
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar producto: $e');
    }
  }

  // ============= MÉTODOS PARA FACTURAS =============

  Future<String> insertarFactura(FacturaModel factura) async {
    try {
      final facturaData = {
        'clienteId': factura.clienteId,
        'nombreCliente': factura.nombreCliente,
        'direccionCliente': factura.direccionCliente,
        'negocioCliente': factura.negocioCliente,
        'rutaCliente': factura.rutaCliente,
        'observacionesCliente': factura.observacionesCliente,
        'fecha': factura.fecha.toIso8601String(),
        'estado': factura.estado,
        'total': factura.total,
      };

      final docRef = await _firestore
          .collection(facturasCol)
          .add(facturaData);

      // Insertar items
      for (var item in factura.items) {
        await _firestore
            .collection(facturasCol)
            .doc(docRef.id)
            .collection(itemFacturasCol)
            .add(item.toMap());
      }

      return docRef.id; // ✅ Retornar String directamente
    } catch (e) {
      throw Exception('Error al insertar factura: $e');
    }
  }

  Future<List<FacturaModel>> obtenerFacturas() async {
    try {
      final snapshot = await _firestore
          .collection(facturasCol)
          .orderBy('fecha', descending: true)
          .get();

      List<FacturaModel> facturas = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Obtener items de la subcolección
        final itemsSnapshot = await _firestore
            .collection(facturasCol)
            .doc(doc.id)
            .collection(itemFacturasCol)
            .get();

        final items = itemsSnapshot.docs
            .map((itemDoc) => ItemFacturaModel.fromMap(itemDoc.data()))
            .toList();

        facturas.add(FacturaModel.fromMap(data, doc.id, items));
      }

      return facturas;
    } catch (e) {
      throw Exception('Error al obtener facturas: $e');
    }
  }

  Future<FacturaModel?> obtenerFacturaPorId(String id) async {
    try {
      final doc = await _firestore
          .collection(facturasCol)
          .doc(id) // ✅ Usar .doc(id) directamente
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        final itemsSnapshot = await _firestore
            .collection(facturasCol)
            .doc(doc.id)
            .collection(itemFacturasCol)
            .get();

        final items = itemsSnapshot.docs
            .map((itemDoc) => ItemFacturaModel.fromMap(itemDoc.data()))
            .toList();

        return FacturaModel.fromMap(data, doc.id, items);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener factura: $e');
    }
  }

  Future<void> actualizarFactura(FacturaModel factura) async {
    try {
      if (factura.id == null) {
        throw Exception('La factura debe tener un ID');
      }

      final docRef = _firestore
          .collection(facturasCol)
          .doc(factura.id);

      await docRef.update({
        'clienteId': factura.clienteId,
        'nombreCliente': factura.nombreCliente,
        'direccionCliente': factura.direccionCliente,
        'negocioCliente': factura.negocioCliente,
        'rutaCliente': factura.rutaCliente,
        'observacionesCliente': factura.observacionesCliente,
        'fecha': factura.fecha.toIso8601String(),
        'estado': factura.estado,
        'total': factura.total,
      });

      // Eliminar items anteriores
      final itemsSnapshot = await docRef.collection(itemFacturasCol).get();
      for (var itemDoc in itemsSnapshot.docs) {
        await itemDoc.reference.delete();
      }

      // Insertar nuevos items
      for (var item in factura.items) {
        await docRef.collection(itemFacturasCol).add(item.toMap());
      }
    } catch (e) {
      throw Exception('Error al actualizar factura: $e');
    }
  }

  Future<void> eliminarFactura(String id) async {
    try {
      final docRef = _firestore
          .collection(facturasCol)
          .doc(id);

      // Eliminar items primero
      final itemsSnapshot = await docRef.collection(itemFacturasCol).get();
      for (var itemDoc in itemsSnapshot.docs) {
        await itemDoc.reference.delete();
      }

      // Eliminar factura
      await docRef.delete();
    } catch (e) {
      throw Exception('Error al eliminar factura: $e');
    }
  }
}