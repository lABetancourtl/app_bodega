class ProductoModel {
  final String? id;
  final String nombre;
  final String categoriaId;
  final List<String> sabores;
  final double precio;
  final int? cantidadPorPaca;
  final String? imagenPath;
  final String? codigoBarras; // Código principal (deprecado pero mantenido por compatibilidad)
  final Map<String, String>? codigosPorSabor; // ← NUEVO: Mapa de sabor -> código de barras

  ProductoModel({
    this.id,
    required this.nombre,
    required this.categoriaId,
    required this.sabores,
    required this.precio,
    this.cantidadPorPaca,
    this.imagenPath,
    this.codigoBarras,
    this.codigosPorSabor, // ← NUEVO
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoriaId': categoriaId,
      'sabores': sabores,
      'precio': precio,
      'cantidadPorPaca': cantidadPorPaca,
      'imagenPath': imagenPath,
      'codigoBarras': codigoBarras,
      'codigosPorSabor': codigosPorSabor, // ← NUEVO
    };
  }

  factory ProductoModel.fromMap(Map<String, dynamic> map, String docId) {
    return ProductoModel(
      id: docId,
      nombre: map['nombre'] as String,
      categoriaId: map['categoriaId'] as String,
      sabores: List<String>.from(map['sabores'] as List),
      precio: (map['precio'] as num).toDouble(),
      cantidadPorPaca: map['cantidadPorPaca'] as int?,
      imagenPath: map['imagenPath'] as String?,
      codigoBarras: map['codigoBarras'] as String?,
      codigosPorSabor: map['codigosPorSabor'] != null // ← NUEVO
          ? Map<String, String>.from(map['codigosPorSabor'] as Map)
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
    Map<String, String>? codigosPorSabor, // ← NUEVO
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
      codigosPorSabor: codigosPorSabor ?? this.codigosPorSabor, // ← NUEVO
    );
  }

  // ← NUEVO: Método helper para obtener todos los códigos de barras
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

  // ← NUEVO: Método helper para obtener el sabor de un código
  String? obtenerSaborPorCodigo(String codigo) {
    if (codigosPorSabor == null) return null;

    for (var entry in codigosPorSabor!.entries) {
      if (entry.value == codigo) {
        return entry.key;
      }
    }

    return null;
  }
}