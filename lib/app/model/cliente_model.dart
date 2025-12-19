// ============= ENUM RUTA =============
enum Ruta { ruta1, ruta2, ruta3 }

// ============= CLIENTE MODEL =============
class ClienteModel {
  final String? id;
  final String nombre;
  final String nombreNegocio;
  final String direccion;
  final String telefono;
  final Ruta ruta;
  final String? observaciones;
  final double? latitud;
  final double? longitud;

  ClienteModel({
    this.id,
    required this.nombre,
    required this.nombreNegocio,
    required this.direccion,
    required this.telefono,
    required this.ruta,
    this.observaciones,
    this.latitud,
    this.longitud,
  });

  // ✅ Para Firestore (sin ID - Firestore lo genera automáticamente)
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'nombreNegocio': nombreNegocio,
      'direccion': direccion,
      'telefono': telefono,
      'ruta': ruta.toString().split('.').last,
      'observaciones': observaciones,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  // ✅ Para Caché (con ID incluido)
  Map<String, dynamic> toJson() {
    return {
      'id': id,  // ⬅️ INCLUIR ID para el caché
      'nombre': nombre,
      'nombreNegocio': nombreNegocio,
      'direccion': direccion,
      'telefono': telefono,
      'ruta': ruta.toString().split('.').last,
      'observaciones': observaciones,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  // ✅ Crear desde Map (para Firestore - ID viene como parámetro)
  factory ClienteModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClienteModel(
      id: docId,
      nombre: map['nombre'] as String? ?? '',  // ⬅️ Valor por defecto
      nombreNegocio: map['nombreNegocio'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      ruta: Ruta.values.firstWhere(
            (e) => e.toString().split('.').last == map['ruta'],
        orElse: () => Ruta.ruta1,
      ),
      observaciones: map['observaciones'] as String?,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
    );
  }

  // ✅ Crear desde JSON (para Caché - ID está dentro del JSON)
  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id'] as String?,  // ⬅️ ID viene del JSON
      nombre: json['nombre'] as String? ?? '',
      nombreNegocio: json['nombreNegocio'] as String? ?? '',
      direccion: json['direccion'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      ruta: Ruta.values.firstWhere(
            (e) => e.toString().split('.').last == json['ruta'],
        orElse: () => Ruta.ruta1,
      ),
      observaciones: json['observaciones'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
    );
  }

  // Copiar con cambios
  ClienteModel copyWith({
    String? id,
    String? nombre,
    String? nombreNegocio,
    String? direccion,
    String? telefono,
    Ruta? ruta,
    String? observaciones,
    double? latitud,
    double? longitud,
  }) {
    return ClienteModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nombreNegocio: nombreNegocio ?? this.nombreNegocio,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      ruta: ruta ?? this.ruta,
      observaciones: observaciones ?? this.observaciones,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
    );
  }

  @override
  String toString() => 'ClienteModel(id: $id, nombre: $nombre, nombreNegocio: $nombreNegocio, direccion: $direccion, telefono: $telefono, ruta: $ruta, observaciones: $observaciones, latitud: $latitud, longitud: $longitud)';
}