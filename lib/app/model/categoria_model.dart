class CategoriaModel {
  final String? id;
  final String nombre;

  CategoriaModel({
    this.id,
    required this.nombre,
  });

  // ✅ FIX: Incluir el ID en toMap para que se guarde en caché
  Map<String, dynamic> toMap() {
    return {
      'id': id,        // ⬅️ ESTO ES CRÍTICO
      'nombre': nombre,
    };
  }

  // ✅ FIX: Asegurar que el ID se lea correctamente
  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'] as String?,  // ⬅️ Conversión explícita
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

  // ✅ Método adicional para JSON (usado por el caché)
  Map<String, dynamic> toJson() => toMap();

  factory CategoriaModel.fromJson(Map<String, dynamic> json) =>
      CategoriaModel.fromMap(json);

  @override
  String toString() => 'CategoriaModel(id: $id, nombre: $nombre)';

  // ✅ Método útil para debugging
  bool get tieneIdValido => id != null && id!.isNotEmpty;
}