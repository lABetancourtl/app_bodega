import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app_pedidos.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        nombreNegocio TEXT NOT NULL,
        direccion TEXT NOT NULL,
        ruta TEXT NOT NULL,
        observaciones TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoriaId INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        sabores TEXT NOT NULL,
        precio REAL NOT NULL,
        cantidadPorPaca INTEGER,
        imagenPath TEXT,
        FOREIGN KEY (categoriaId) REFERENCES categorias (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE facturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER NOT NULL,
        nombreCliente TEXT NOT NULL,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        FOREIGN KEY (clienteId) REFERENCES clientes (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE item_facturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        facturaId INTEGER NOT NULL,
        productoId INTEGER NOT NULL,
        nombreProducto TEXT NOT NULL,
        precioUnitario REAL NOT NULL,
        cantidadTotal INTEGER NOT NULL,
        cantidadPorSabor TEXT NOT NULL,
        tieneSabores INTEGER NOT NULL,
        FOREIGN KEY (facturaId) REFERENCES facturas (id),
        FOREIGN KEY (productoId) REFERENCES productos (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE categorias (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL UNIQUE
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          categoriaId INTEGER NOT NULL,
          nombre TEXT NOT NULL,
          sabores TEXT NOT NULL,
          precio REAL NOT NULL,
          cantidadPorPaca INTEGER,
          FOREIGN KEY (categoriaId) REFERENCES categorias (id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE facturas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          clienteId INTEGER NOT NULL,
          nombreCliente TEXT NOT NULL,
          fecha TEXT NOT NULL,
          estado TEXT NOT NULL,
          FOREIGN KEY (clienteId) REFERENCES clientes (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE item_facturas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          facturaId INTEGER NOT NULL,
          productoId INTEGER NOT NULL,
          nombreProducto TEXT NOT NULL,
          precioUnitario REAL NOT NULL,
          cantidadTotal INTEGER NOT NULL,
          cantidadPorSabor TEXT NOT NULL,
          tieneSabores INTEGER NOT NULL,
          FOREIGN KEY (facturaId) REFERENCES facturas (id),
          FOREIGN KEY (productoId) REFERENCES productos (id)
        )
      ''');
    }
    if (oldVersion < 5) {
      // Agregar la columna imagenPath a productos
      await db.execute('ALTER TABLE productos ADD COLUMN imagenPath TEXT');
    }
  }

  // MÉTODOS PARA CLIENTES
  Future<int> insertarCliente(ClienteModel cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente.toMap());
  }

  Future<List<ClienteModel>> obtenerClientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('clientes');
    return List.generate(maps.length, (i) => ClienteModel.fromMap(maps[i]));
  }

  Future<ClienteModel?> obtenerClientePorId(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ClienteModel.fromMap(maps[0]);
    }
    return null;
  }

  Future<int> actualizarCliente(ClienteModel cliente) async {
    final db = await database;
    return await db.update(
      'clientes',
      cliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  Future<int> eliminarCliente(int id) async {
    final db = await database;
    return await db.delete(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MÉTODOS PARA CATEGORÍAS
  Future<int> insertarCategoria(CategoriaModel categoria) async {
    final db = await database;
    return await db.insert('categorias', categoria.toMap());
  }

  Future<List<CategoriaModel>> obtenerCategorias() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categorias');
    return List.generate(maps.length, (i) => CategoriaModel.fromMap(maps[i]));
  }

  Future<CategoriaModel?> obtenerCategoriaPorId(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CategoriaModel.fromMap(maps[0]);
    }
    return null;
  }

  Future<int> actualizarCategoria(CategoriaModel categoria) async {
    final db = await database;
    return await db.update(
      'categorias',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  Future<int> eliminarCategoria(int id) async {
    final db = await database;
    return await db.delete(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MÉTODOS PARA PRODUCTOS
  Future<int> insertarProducto(ProductoModel producto) async {
    final db = await database;
    return await db.insert('productos', producto.toMap());
  }

  Future<List<ProductoModel>> obtenerProductos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('productos');
    return List.generate(maps.length, (i) => ProductoModel.fromMap(maps[i]));
  }

  Future<List<ProductoModel>> obtenerProductosPorCategoria(int categoriaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'productos',
      where: 'categoriaId = ?',
      whereArgs: [categoriaId],
    );
    return List.generate(maps.length, (i) => ProductoModel.fromMap(maps[i]));
  }

  Future<ProductoModel?> obtenerProductoPorId(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ProductoModel.fromMap(maps[0]);
    }
    return null;
  }

  Future<int> actualizarProducto(ProductoModel producto) async {
    final db = await database;
    return await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  Future<int> eliminarProducto(int id) async {
    final db = await database;
    return await db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MÉTODOS PARA FACTURAS
  Future<int> insertarFactura(FacturaModel factura) async {
    final db = await database;

    // Insertar la factura
    final facturaId = await db.insert('facturas', {
      'clienteId': factura.clienteId as int,
      'nombreCliente': factura.nombreCliente as String,
      'fecha': factura.fecha.toIso8601String() as String,
      'estado': factura.estado as String,
    });

    // Insertar los items de la factura
    for (var item in factura.items) {
      await db.insert('item_facturas', {
        'facturaId': facturaId as int,
        'productoId': item.productoId as int,
        'nombreProducto': item.nombreProducto as String,
        'precioUnitario': item.precioUnitario as double,
        'cantidadTotal': item.cantidadTotal as int,
        'cantidadPorSabor': item.cantidadPorSabor.toString() as String,
        'tieneSabores': item.tieneSabores ? 1 : 0 as int,
      });
    }

    return facturaId;
  }

  Future<List<FacturaModel>> obtenerFacturas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('facturas');

    List<FacturaModel> facturas = [];
    for (var map in maps) {
      final factura = FacturaModel.fromMap(map);

      // Obtener la información completa del cliente
      final cliente = await obtenerClientePorId(factura.clienteId);

      // Obtener los items de esta factura
      final itemMaps = await db.query(
        'item_facturas',
        where: 'facturaId = ?',
        whereArgs: [factura.id],
      );

      final items = itemMaps.map((itemMap) {
        // Parsear el cantidadPorSabor del string
        Map<String, int> cantidadPorSabor = {};
        final cantidadStr = itemMap['cantidadPorSabor'] as String;
        if (cantidadStr.isNotEmpty && cantidadStr != '{}') {
          // Remover las llaves y parsear
          final content = cantidadStr.replaceAll('{', '').replaceAll('}', '');
          final pares = content.split(', ');
          for (var par in pares) {
            if (par.contains(':')) {
              final partes = par.split(': ');
              if (partes.length == 2) {
                final sabor = partes[0].replaceAll('\'', '').trim();
                final cantidad = int.tryParse(partes[1]) ?? 0;
                cantidadPorSabor[sabor] = cantidad;
              }
            }
          }
        }

        return ItemFacturaModel(
          productoId: itemMap['productoId'] as int,
          nombreProducto: itemMap['nombreProducto'] as String,
          precioUnitario: itemMap['precioUnitario'] as double,
          cantidadTotal: itemMap['cantidadTotal'] as int,
          cantidadPorSabor: cantidadPorSabor,
          tieneSabores: (itemMap['tieneSabores'] as int) == 1,
        );
      }).toList();

      facturas.add(FacturaModel(
        id: factura.id,
        clienteId: factura.clienteId,
        nombreCliente: cliente?.nombre ?? factura.nombreCliente,
        direccionCliente: cliente?.direccion,
        negocioCliente: cliente?.nombreNegocio,
        rutaCliente: cliente?.ruta.toString().split('.').last.toUpperCase(),
        observacionesCliente: cliente?.observaciones,
        fecha: factura.fecha,
        items: items,
        estado: factura.estado,
      ));
    }

    return facturas;
  }

  Future<FacturaModel?> obtenerFacturaPorId(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'facturas',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final factura = FacturaModel.fromMap(maps[0]);

      // Obtener la información completa del cliente
      final cliente = await obtenerClientePorId(factura.clienteId);

      // Obtener los items de esta factura
      final itemMaps = await db.query(
        'item_facturas',
        where: 'facturaId = ?',
        whereArgs: [factura.id],
      );

      final items = itemMaps.map((itemMap) {
        // Parsear el cantidadPorSabor del string
        Map<String, int> cantidadPorSabor = {};
        final cantidadStr = itemMap['cantidadPorSabor'] as String;
        if (cantidadStr.isNotEmpty && cantidadStr != '{}') {
          // Remover las llaves y parsear
          final content = cantidadStr.replaceAll('{', '').replaceAll('}', '');
          final pares = content.split(', ');
          for (var par in pares) {
            if (par.contains(':')) {
              final partes = par.split(': ');
              if (partes.length == 2) {
                final sabor = partes[0].replaceAll('\'', '').trim();
                final cantidad = int.tryParse(partes[1]) ?? 0;
                cantidadPorSabor[sabor] = cantidad;
              }
            }
          }
        }

        return ItemFacturaModel(
          productoId: itemMap['productoId'] as int,
          nombreProducto: itemMap['nombreProducto'] as String,
          precioUnitario: itemMap['precioUnitario'] as double,
          cantidadTotal: itemMap['cantidadTotal'] as int,
          cantidadPorSabor: cantidadPorSabor,
          tieneSabores: (itemMap['tieneSabores'] as int) == 1,
        );
      }).toList();

      return FacturaModel(
        id: factura.id,
        clienteId: factura.clienteId,
        nombreCliente: cliente?.nombre ?? factura.nombreCliente,
        direccionCliente: cliente?.direccion,
        negocioCliente: cliente?.nombreNegocio,
        rutaCliente: cliente?.ruta.toString().split('.').last.toUpperCase(),
        observacionesCliente: cliente?.observaciones,
        fecha: factura.fecha,
        items: items,
        estado: factura.estado,
      );
    }
    return null;
  }

  Future<int> actualizarFactura(FacturaModel factura) async {
    final db = await database;

    // Actualizar la factura
    await db.update(
      'facturas',
      {
        'clienteId': factura.clienteId as int,
        'nombreCliente': factura.nombreCliente as String,
        'fecha': factura.fecha.toIso8601String() as String,
        'estado': factura.estado as String,
      },
      where: 'id = ?',
      whereArgs: [factura.id],
    );

    // Eliminar los items antiguos
    await db.delete(
      'item_facturas',
      where: 'facturaId = ?',
      whereArgs: [factura.id],
    );

    // Insertar los nuevos items
    for (var item in factura.items) {
      await db.insert('item_facturas', {
        'facturaId': factura.id as int,
        'productoId': item.productoId as int,
        'nombreProducto': item.nombreProducto as String,
        'precioUnitario': item.precioUnitario as double,
        'cantidadTotal': item.cantidadTotal as int,
        'cantidadPorSabor': item.cantidadPorSabor.toString() as String,
        'tieneSabores': item.tieneSabores ? 1 : 0 as int,
      });
    }

    return 1;
  }

  Future<int> eliminarFactura(int id) async {
    final db = await database;
    return await db.delete(
      'facturas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cerrar la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}