// ============= ITEM FACTURA MODEL =============
class ItemFacturaModel {
  final String productoId;  // ✅ Ya es String
  final String nombreProducto;
  final double precioUnitario;
  final int cantidadTotal;
  final Map<String, int> cantidadPorSabor;
  final bool tieneSabores;

  ItemFacturaModel({
    required this.productoId,
    required this.nombreProducto,
    required this.precioUnitario,
    required this.cantidadTotal,
    required this.cantidadPorSabor,
    required this.tieneSabores,
  });

  double get subtotal => precioUnitario * cantidadTotal;

  // Convertir a Map (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombreProducto': nombreProducto,
      'precioUnitario': precioUnitario,
      'cantidadTotal': cantidadTotal,
      'cantidadPorSabor': cantidadPorSabor,
      'tieneSabores': tieneSabores,
    };
  }

  // Crear desde Map (para leer de Firestore)
  factory ItemFacturaModel.fromMap(Map<String, dynamic> map) {
    return ItemFacturaModel(
      productoId: map['productoId'] as String,
      nombreProducto: map['nombreProducto'] as String,
      precioUnitario: (map['precioUnitario'] as num).toDouble(),
      cantidadTotal: map['cantidadTotal'] as int,
      cantidadPorSabor: Map<String, int>.from(map['cantidadPorSabor'] as Map? ?? {}),
      tieneSabores: map['tieneSabores'] as bool,
    );
  }

  ItemFacturaModel copyWith({
    String? productoId,
    String? nombreProducto,
    double? precioUnitario,
    int? cantidadTotal,
    Map<String, int>? cantidadPorSabor,
    bool? tieneSabores,
  }) {
    return ItemFacturaModel(
      productoId: productoId ?? this.productoId,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      cantidadTotal: cantidadTotal ?? this.cantidadTotal,
      cantidadPorSabor: cantidadPorSabor ?? this.cantidadPorSabor,
      tieneSabores: tieneSabores ?? this.tieneSabores,
    );
  }

  @override
  String toString() => 'ItemFacturaModel(productoId: $productoId, nombreProducto: $nombreProducto, precioUnitario: $precioUnitario, cantidadTotal: $cantidadTotal, cantidadPorSabor: $cantidadPorSabor, tieneSabores: $tieneSabores)';
}

// ============= FACTURA MODEL =============
class FacturaModel {
  final String? id;  // ← CAMBIO: int? → String?
  final String clienteId;  // ← CAMBIO: int → String
  final String nombreCliente;
  final String? direccionCliente;
  final String? negocioCliente;
  final String? rutaCliente;
  final String? observacionesCliente;
  final DateTime fecha;
  final List<ItemFacturaModel> items;
  final String estado;

  FacturaModel({
    this.id,
    required this.clienteId,
    required this.nombreCliente,
    this.direccionCliente,
    this.negocioCliente,
    this.rutaCliente,
    this.observacionesCliente,
    required this.fecha,
    required this.items,
    this.estado = 'pendiente',
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  // Convertir a Map (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'direccionCliente': direccionCliente,
      'negocioCliente': negocioCliente,
      'rutaCliente': rutaCliente,
      'observacionesCliente': observacionesCliente,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
      'total': total,
    };
  }

  // Crear desde Map (para leer de Firestore)
  // NOTA: Este factory ya no se usará, usa el de DatabaseHelper que recibe docId
  factory FacturaModel.fromMap(Map<String, dynamic> map, String docId, List<ItemFacturaModel> items) {
    return FacturaModel(
      id: docId,  // ← Usar el docId de Firestore
      clienteId: map['clienteId'] as String,  // ← Ahora es String
      nombreCliente: map['nombreCliente'] as String,
      direccionCliente: map['direccionCliente'] as String?,
      negocioCliente: map['negocioCliente'] as String?,
      rutaCliente: map['rutaCliente'] as String?,
      observacionesCliente: map['observacionesCliente'] as String?,
      fecha: DateTime.parse(map['fecha'] as String),
      items: items,  // ← Pasar los items cargados de la subcolección
      estado: map['estado'] as String? ?? 'pendiente',
    );
  }

  // Copiar con cambios
  FacturaModel copyWith({
    String? id,  // ← CAMBIO: int? → String?
    String? clienteId,  // ← CAMBIO: int? → String?
    String? nombreCliente,
    String? direccionCliente,
    String? negocioCliente,
    String? rutaCliente,
    String? observacionesCliente,
    DateTime? fecha,
    List<ItemFacturaModel>? items,
    String? estado,
  }) {
    return FacturaModel(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      direccionCliente: direccionCliente ?? this.direccionCliente,
      negocioCliente: negocioCliente ?? this.negocioCliente,
      rutaCliente: rutaCliente ?? this.rutaCliente,
      observacionesCliente: observacionesCliente ?? this.observacionesCliente,
      fecha: fecha ?? this.fecha,
      items: items ?? this.items,
      estado: estado ?? this.estado,
    );
  }

  @override
  String toString() => 'FacturaModel(id: $id, clienteId: $clienteId, nombreCliente: $nombreCliente, direccionCliente: $direccionCliente, negocioCliente: $negocioCliente, rutaCliente: $rutaCliente, observacionesCliente: $observacionesCliente, fecha: $fecha, items: $items, estado: $estado)';
}