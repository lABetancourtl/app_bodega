class CategoriaModel {
  final String? id;
  final String nombre;

  CategoriaModel({
    this.id,
    required this.nombre,
  });

  // Convertir a Map (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
    };
  }

  // Crear desde Map (para leer de Firestore)
  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'],
      nombre: map['nombre'] as String,
    );
  }

  // Copiar con cambios
  CategoriaModel copyWith({
    String? id,
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