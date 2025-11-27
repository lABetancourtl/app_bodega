// ============= ENUM RUTA =============
enum Ruta { ruta1, ruta2, ruta3 }

// ============= CLIENTE MODEL =============
class ClienteModel {
  final String? id;  // ✅ Cambio: int? → String?
  final String nombre;
  final String nombreNegocio;
  final String direccion;
  final Ruta ruta;
  final String? observaciones;

  ClienteModel({
    this.id,
    required this.nombre,
    required this.nombreNegocio,
    required this.direccion,
    required this.ruta,
    this.observaciones,
  });

  // Convertir a Map (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      // ✅ NO incluir 'id' en toMap() - Firestore lo maneja automáticamente
      'nombre': nombre,
      'nombreNegocio': nombreNegocio,
      'direccion': direccion,
      'ruta': ruta.toString().split('.').last,  // Guardar como String: 'ruta1', 'ruta2', etc.
      'observaciones': observaciones,
    };
  }

  // Crear desde Map (para leer de Firestore)
  factory ClienteModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClienteModel(
      id: docId,  // ✅ Pasar el docId de Firestore
      nombre: map['nombre'] as String,
      nombreNegocio: map['nombreNegocio'] as String,
      direccion: map['direccion'] as String,
      ruta: Ruta.values.firstWhere(
            (e) => e.toString().split('.').last == map['ruta'],
        orElse: () => Ruta.ruta1,  // ✅ Valor por defecto en caso de error
      ),
      observaciones: map['observaciones'] as String?,
    );
  }

  // Copiar con cambios
  ClienteModel copyWith({
    String? id,  // ✅ Cambio: int? → String?
    String? nombre,
    String? nombreNegocio,
    String? direccion,
    Ruta? ruta,
    String? observaciones,
  }) {
    return ClienteModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nombreNegocio: nombreNegocio ?? this.nombreNegocio,
      direccion: direccion ?? this.direccion,
      ruta: ruta ?? this.ruta,
      observaciones: observaciones ?? this.observaciones,
    );
  }

  @override
  String toString() => 'ClienteModel(id: $id, nombre: $nombre, nombreNegocio: $nombreNegocio, direccion: $direccion, ruta: $ruta, observaciones: $observaciones)';
}