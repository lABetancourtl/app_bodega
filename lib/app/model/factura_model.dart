class ItemFacturaModel {
  final int productoId;
  final String nombreProducto;
  final double precioUnitario;
  final int cantidadTotal;
  final Map<String, int> cantidadPorSabor; // sabor -> cantidad
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

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombreProducto': nombreProducto,
      'precioUnitario': precioUnitario,
      'cantidadTotal': cantidadTotal,
      'cantidadPorSabor': cantidadPorSabor.toString(),
      'tieneSabores': tieneSabores ? 1 : 0,
    };
  }

  factory ItemFacturaModel.fromMap(Map<String, dynamic> map) {
    return ItemFacturaModel(
      productoId: map['productoId'],
      nombreProducto: map['nombreProducto'],
      precioUnitario: map['precioUnitario'],
      cantidadTotal: map['cantidadTotal'],
      cantidadPorSabor: {},
      tieneSabores: map['tieneSabores'] == 1,
    );
  }
}

class FacturaModel {
  final int? id;
  final int clienteId;
  final String nombreCliente;
  final DateTime fecha;
  final List<ItemFacturaModel> items;
  final String estado; // pendiente, completada, cancelada

  FacturaModel({
    this.id,
    required this.clienteId,
    required this.nombreCliente,
    required this.fecha,
    required this.items,
    this.estado = 'pendiente',
  });

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
    };
  }

  factory FacturaModel.fromMap(Map<String, dynamic> map) {
    return FacturaModel(
      id: map['id'],
      clienteId: map['clienteId'],
      nombreCliente: map['nombreCliente'],
      fecha: DateTime.parse(map['fecha']),
      items: [],
      estado: map['estado'] ?? 'pendiente',
    );
  }
}