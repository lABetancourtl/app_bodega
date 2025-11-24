import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/cliente_model.dart';
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
      version: 3,
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
        FOREIGN KEY (categoriaId) REFERENCES categorias (id)
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
  }

  // Insertar cliente
  Future<int> insertarCliente(ClienteModel cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente.toMap());
  }

  // Obtener todos los clientes
  Future<List<ClienteModel>> obtenerClientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('clientes');
    return List.generate(maps.length, (i) => ClienteModel.fromMap(maps[i]));
  }

  // Obtener cliente por ID
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

  // Actualizar cliente
  Future<int> actualizarCliente(ClienteModel cliente) async {
    final db = await database;
    return await db.update(
      'clientes',
      cliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  // Eliminar cliente
  Future<int> eliminarCliente(int id) async {
    final db = await database;
    return await db.delete(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cerrar la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // MÉTODOS PARA CATEGORÍAS

  // Insertar categoría
  Future<int> insertarCategoria(CategoriaModel categoria) async {
    final db = await database;
    return await db.insert('categorias', categoria.toMap());
  }

  // Obtener todas las categorías
  Future<List<CategoriaModel>> obtenerCategorias() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categorias');
    return List.generate(maps.length, (i) => CategoriaModel.fromMap(maps[i]));
  }

  // Obtener categoría por ID
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

  // Actualizar categoría
  Future<int> actualizarCategoria(CategoriaModel categoria) async {
    final db = await database;
    return await db.update(
      'categorias',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  // Eliminar categoría
  Future<int> eliminarCategoria(int id) async {
    final db = await database;
    return await db.delete(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MÉTODOS PARA PRODUCTOS

  // Insertar producto
  Future<int> insertarProducto(ProductoModel producto) async {
    final db = await database;
    return await db.insert('productos', producto.toMap());
  }

  // Obtener todos los productos
  Future<List<ProductoModel>> obtenerProductos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('productos');
    return List.generate(maps.length, (i) => ProductoModel.fromMap(maps[i]));
  }

  // Obtener productos por categoría
  Future<List<ProductoModel>> obtenerProductosPorCategoria(int categoriaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'productos',
      where: 'categoriaId = ?',
      whereArgs: [categoriaId],
    );
    return List.generate(maps.length, (i) => ProductoModel.fromMap(maps[i]));
  }

  // Obtener producto por ID
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

  // Actualizar producto
  Future<int> actualizarProducto(ProductoModel producto) async {
    final db = await database;
    return await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  // Eliminar producto
  Future<int> eliminarProducto(int id) async {
    final db = await database;
    return await db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}