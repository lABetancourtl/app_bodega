class ProductoModel {
  final String? id;
  final String nombre;
  final String categoriaId;
  final List<String> sabores;
  final double precio;
  final int? cantidadPorPaca;
  final String? imagenPath;
  final String? codigoBarras;
  final Map<String, String>? codigosPorSabor;

  ProductoModel({
    this.id,
    required this.nombre,
    required this.categoriaId,
    required this.sabores,
    required this.precio,
    this.cantidadPorPaca,
    this.imagenPath,
    this.codigoBarras,
    this.codigosPorSabor,
  });

  // ✅ Para Firestore (sin ID - Firestore lo genera automáticamente)
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoriaId': categoriaId,
      'sabores': sabores,
      'precio': precio,
      'cantidadPorPaca': cantidadPorPaca,
      'imagenPath': imagenPath,
      'codigoBarras': codigoBarras,
      'codigosPorSabor': codigosPorSabor,
    };
  }

  // ✅ Para Caché (con ID incluido)
  Map<String, dynamic> toJson() {
    return {
      'id': id,  // ⬅️ INCLUIR ID para el caché
      'nombre': nombre,
      'categoriaId': categoriaId,
      'sabores': sabores,
      'precio': precio,
      'cantidadPorPaca': cantidadPorPaca,
      'imagenPath': imagenPath,
      'codigoBarras': codigoBarras,
      'codigosPorSabor': codigosPorSabor,
    };
  }

  // ✅ Crear desde Map (para Firestore - ID viene como parámetro)
  factory ProductoModel.fromMap(Map<String, dynamic> map, String docId) {
    return ProductoModel(
      id: docId,
      nombre: map['nombre'] as String? ?? '',  // ⬅️ Valor por defecto
      categoriaId: map['categoriaId'] as String? ?? '',
      sabores: (map['sabores'] as List?)?.cast<String>() ?? [],
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      cantidadPorPaca: map['cantidadPorPaca'] as int?,
      imagenPath: map['imagenPath'] as String?,
      codigoBarras: map['codigoBarras'] as String?,
      codigosPorSabor: map['codigosPorSabor'] != null
          ? Map<String, String>.from(map['codigosPorSabor'] as Map)
          : null,
    );
  }

  // ✅ Crear desde JSON (para Caché - ID está dentro del JSON)
  factory ProductoModel.fromJson(Map<String, dynamic> json) {
    return ProductoModel(
      id: json['id'] as String?,  // ⬅️ ID viene del JSON
      nombre: json['nombre'] as String? ?? '',
      categoriaId: json['categoriaId'] as String? ?? '',
      sabores: (json['sabores'] as List?)?.cast<String>() ?? [],
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      cantidadPorPaca: json['cantidadPorPaca'] as int?,
      imagenPath: json['imagenPath'] as String?,
      codigoBarras: json['codigoBarras'] as String?,
      codigosPorSabor: json['codigosPorSabor'] != null
          ? Map<String, String>.from(json['codigosPorSabor'] as Map)
          : null,
    );
  }

  ProductoModel copyWith({
    String? id,
    String? nombre,
    String? categoriaId,
    List<String>? sabores,
    double? precio,
    int? cantidadPorPaca,
    String? imagenPath,
    String? codigoBarras,
    Map<String, String>? codigosPorSabor,
  }) {
    return ProductoModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoriaId: categoriaId ?? this.categoriaId,
      sabores: sabores ?? this.sabores,
      precio: precio ?? this.precio,
      cantidadPorPaca: cantidadPorPaca ?? this.cantidadPorPaca,
      imagenPath: imagenPath ?? this.imagenPath,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      codigosPorSabor: codigosPorSabor ?? this.codigosPorSabor,
    );
  }

  // Método helper para obtener todos los códigos de barras
  List<String> obtenerTodosLosCodigos() {
    final List<String> codigos = [];

    // Agregar código principal si existe
    if (codigoBarras != null && codigoBarras!.isNotEmpty) {
      codigos.add(codigoBarras!);
    }

    // Agregar códigos por sabor si existen
    if (codigosPorSabor != null) {
      codigos.addAll(codigosPorSabor!.values);
    }

    return codigos;
  }

  // Método helper para obtener el sabor de un código
  String? obtenerSaborPorCodigo(String codigo) {
    if (codigosPorSabor == null) return null;

    for (var entry in codigosPorSabor!.entries) {
      if (entry.value == codigo) {
        return entry.key;
      }
    }

    return null;
  }

  @override
  String toString() => 'ProductoModel(id: $id, nombre: $nombre, categoriaId: $categoriaId)';
}