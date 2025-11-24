class ProductoModel {
  final int? id;
  final int categoriaId;
  final String nombre;
  final List<String> sabores;
  final double precio;
  final int? cantidadPorPaca;

  ProductoModel({
    this.id,
    required this.categoriaId,
    required this.nombre,
    required this.sabores,
    required this.precio,
    this.cantidadPorPaca,
  });

  // Convertir a Map (para guardar en BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoriaId': categoriaId,
      'nombre': nombre,
      'sabores': sabores.join(','), // Guardar como string separado por comas
      'precio': precio,
      'cantidadPorPaca': cantidadPorPaca,
    };
  }

  // Crear desde Map (para leer de BD)
  factory ProductoModel.fromMap(Map<String, dynamic> map) {
    return ProductoModel(
      id: map['id'],
      categoriaId: map['categoriaId'],
      nombre: map['nombre'],
      sabores: (map['sabores'] as String).split(','),
      precio: map['precio'],
      cantidadPorPaca: map['cantidadPorPaca'],
    );
  }

  // Copiar con cambios
  ProductoModel copyWith({
    int? id,
    int? categoriaId,
    String? nombre,
    List<String>? sabores,
    double? precio,
    int? cantidadPorPaca,
  }) {
    return ProductoModel(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      sabores: sabores ?? this.sabores,
      precio: precio ?? this.precio,
      cantidadPorPaca: cantidadPorPaca ?? this.cantidadPorPaca,
    );
  }

  @override
  String toString() => 'ProductoModel(id: $id, categoriaId: $categoriaId, nombre: $nombre, sabores: $sabores, precio: $precio, cantidadPorPaca: $cantidadPorPaca)';
}