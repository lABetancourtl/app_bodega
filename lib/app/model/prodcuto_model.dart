class ProductoModel {
  final String? id;
  final String nombre;
  final String categoriaId;
  final List<String> sabores;
  final double precio;
  final int? cantidadPorPaca;
  final String? imagenPath;
  final String? codigoBarras;

  ProductoModel({
    this.id,
    required this.nombre,
    required this.categoriaId,
    required this.sabores,
    required this.precio,
    this.cantidadPorPaca,
    this.imagenPath,
    this.codigoBarras,
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
    );
  }
}