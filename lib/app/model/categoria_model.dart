class CategoriaModel {
  final int? id;
  final String nombre;

  CategoriaModel({
    this.id,
    required this.nombre,
  });

  // Convertir a Map (para guardar en BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  // Crear desde Map (para leer de BD)
  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'],
      nombre: map['nombre'],
    );
  }

  // Copiar con cambios
  CategoriaModel copyWith({
    int? id,
    String? nombre,
  }) {
    return CategoriaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
    );
  }

  @override
  String toString() => 'CategoriaModel(id: $id, nombre: $nombre)';
}