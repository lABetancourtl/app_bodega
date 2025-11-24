enum Ruta { ruta1, ruta2, ruta3 }

class ClienteModel {
  final int? id;
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

  // Convertir a Map (para guardar en BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'nombreNegocio': nombreNegocio,
      'direccion': direccion,
      'ruta': ruta.toString().split('.').last,
      'observaciones': observaciones,
    };
  }

  // Crear desde Map (para leer de BD)
  factory ClienteModel.fromMap(Map<String, dynamic> map) {
    return ClienteModel(
      id: map['id'],
      nombre: map['nombre'],
      nombreNegocio: map['nombreNegocio'],
      direccion: map['direccion'],
      ruta: Ruta.values.firstWhere(
            (e) => e.toString().split('.').last == map['ruta'],
      ),
      observaciones: map['observaciones'],
    );
  }

  // Copiar con cambios
  ClienteModel copyWith({
    int? id,
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