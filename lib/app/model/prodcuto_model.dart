class ProductoModel {
  final String? id;  // ← Cambiar de int? a String?
  final String nombre;
  final String categoriaId;  // ← Ya debe ser String
  final List<String> sabores;
  final double precio;
  final int? cantidadPorPaca;
  final String? imagenPath;

  ProductoModel({
    this.id,
    required this.nombre,
    required this.categoriaId,
    required this.sabores,
    required this.precio,
    this.cantidadPorPaca,
    this.imagenPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoriaId': categoriaId,
      'sabores': sabores,
      'precio': precio,
      'cantidadPorPaca': cantidadPorPaca,
      'imagenPath': imagenPath,
    };
  }

  factory ProductoModel.fromMap(Map<String, dynamic> map, String docId) {
    return ProductoModel(
      id: docId,  // ← Pasar el ID del documento
      nombre: map['nombre'] as String,
      categoriaId: map['categoriaId'] as String,
      sabores: List<String>.from(map['sabores'] as List),
      precio: (map['precio'] as num).toDouble(),
      cantidadPorPaca: map['cantidadPorPaca'] as int?,
      imagenPath: map['imagenPath'] as String?,
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
  }) {
    return ProductoModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoriaId: categoriaId ?? this.categoriaId,
      sabores: sabores ?? this.sabores,
      precio: precio ?? this.precio,
      cantidadPorPaca: cantidadPorPaca ?? this.cantidadPorPaca,
      imagenPath: imagenPath ?? this.imagenPath,
    );
  }
}
