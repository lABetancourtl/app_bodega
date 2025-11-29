// ============= ENUM RUTA =============
enum Ruta { ruta1, ruta2, ruta3 }

// ============= CLIENTE MODEL =============
class ClienteModel {
  final String? id;
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

      'nombre': nombre,
      'nombreNegocio': nombreNegocio,
      'direccion': direccion,
      'ruta': ruta.toString().split('.').last,
      'observaciones': observaciones,
    };
  }

  // Crear desde Map (para leer de Firestore)
  factory ClienteModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClienteModel(
      id: docId,
      nombre: map['nombre'] as String,
      nombreNegocio: map['nombreNegocio'] as String,
      direccion: map['direccion'] as String,
      ruta: Ruta.values.firstWhere(
            (e) => e.toString().split('.').last == map['ruta'],
        orElse: () => Ruta.ruta1,
      ),
      observaciones: map['observaciones'] as String?,
    );
  }

  // Copiar con cambios
  ClienteModel copyWith({
    String? id,
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