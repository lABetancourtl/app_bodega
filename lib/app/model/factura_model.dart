// ============= ENUM PARA TIPO DE DESCUENTO =============
enum TipoDescuento {
  porcentaje,  // Ej: 10%
  monto,       // Ej: $5000
  ninguno
}

// ============= MODELO DE DESCUENTO =============
class DescuentoModel {
  final TipoDescuento tipo;
  final double valor;
  final String? motivo; // Opcional: "Cliente frecuente", "Promoción", etc.

  DescuentoModel({
    required this.tipo,
    required this.valor,
    this.motivo,
  });

  // Calcular el monto de descuento basado en un precio
  double calcularDescuento(double precioBase) {
    switch (tipo) {
      case TipoDescuento.porcentaje:
        return precioBase * (valor / 100);
      case TipoDescuento.monto:
        return valor;
      case TipoDescuento.ninguno:
        return 0;
    }
  }

  // Calcular precio final después del descuento
  double aplicarDescuento(double precioBase) {
    return precioBase - calcularDescuento(precioBase);
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.name,
      'valor': valor,
      'motivo': motivo,
    };
  }

  factory DescuentoModel.fromMap(Map<String, dynamic> map) {
    return DescuentoModel(
      tipo: TipoDescuento.values.firstWhere(
            (e) => e.name == map['tipo'],
        orElse: () => TipoDescuento.ninguno,
      ),
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      motivo: map['motivo'] as String?,
    );
  }

  // Factory para crear descuento vacío
  factory DescuentoModel.sinDescuento() {
    return DescuentoModel(tipo: TipoDescuento.ninguno, valor: 0);
  }

  bool get tieneDescuento => tipo != TipoDescuento.ninguno && valor > 0;

  @override
  String toString() {
    if (tipo == TipoDescuento.porcentaje) {
      return '$valor%';
    } else if (tipo == TipoDescuento.monto) {
      return '\$$valor';
    }
    return 'Sin descuento';
  }
}

// ============= ITEM FACTURA MODEL ACTUALIZADO =============
class ItemFacturaModel {
  final String productoId;
  final String nombreProducto;
  final double precioUnitario; // Precio original
  final int cantidadTotal;
  final Map<String, int> cantidadPorSabor;
  final bool tieneSabores;
  final DescuentoModel? descuento; // ← NUEVO

  ItemFacturaModel({
    required this.productoId,
    required this.nombreProducto,
    required this.precioUnitario,
    required this.cantidadTotal,
    required this.cantidadPorSabor,
    required this.tieneSabores,
    this.descuento,
  });

  // Precio unitario con descuento aplicado
  double get precioUnitarioConDescuento {
    if (descuento != null && descuento!.tieneDescuento) {
      return descuento!.aplicarDescuento(precioUnitario);
    }
    return precioUnitario;
  }

  // Subtotal sin descuento
  double get subtotalSinDescuento => precioUnitario * cantidadTotal;

  // Subtotal con descuento aplicado
  double get subtotal => precioUnitarioConDescuento * cantidadTotal;

  // Monto total de descuento en este item
  double get montoDescuento => subtotalSinDescuento - subtotal;

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombreProducto': nombreProducto,
      'precioUnitario': precioUnitario,
      'cantidadTotal': cantidadTotal,
      'cantidadPorSabor': cantidadPorSabor,
      'tieneSabores': tieneSabores,
      'descuento': descuento?.toMap(),
    };
  }

  factory ItemFacturaModel.fromMap(Map<String, dynamic> map) {
    return ItemFacturaModel(
      productoId: map['productoId'] as String,
      nombreProducto: map['nombreProducto'] as String,
      precioUnitario: (map['precioUnitario'] as num).toDouble(),
      cantidadTotal: map['cantidadTotal'] as int,
      cantidadPorSabor: Map<String, int>.from(map['cantidadPorSabor'] as Map? ?? {}),
      tieneSabores: map['tieneSabores'] as bool,
      descuento: map['descuento'] != null
          ? DescuentoModel.fromMap(map['descuento'] as Map<String, dynamic>)
          : null,
    );
  }

  ItemFacturaModel copyWith({
    String? productoId,
    String? nombreProducto,
    double? precioUnitario,
    int? cantidadTotal,
    Map<String, int>? cantidadPorSabor,
    bool? tieneSabores,
    DescuentoModel? descuento,
    bool eliminarDescuento = false, // Para poder remover el descuento
  }) {
    return ItemFacturaModel(
      productoId: productoId ?? this.productoId,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      cantidadTotal: cantidadTotal ?? this.cantidadTotal,
      cantidadPorSabor: cantidadPorSabor ?? this.cantidadPorSabor,
      tieneSabores: tieneSabores ?? this.tieneSabores,
      descuento: eliminarDescuento ? null : (descuento ?? this.descuento),
    );
  }
}

// ============= FACTURA MODEL ACTUALIZADO =============
class FacturaModel {
  final String? id;
  final String clienteId;
  final String nombreCliente;
  final String direccionCliente;
  final String? telefonoCliente;
  final String? negocioCliente;
  final String? rutaCliente;
  final String? observacionesCliente;
  final DateTime fecha;
  final List<ItemFacturaModel> items;
  final String estado;
  final DescuentoModel? descuentoGlobal; // ← NUEVO: Descuento a toda la factura

  FacturaModel({
    this.id,
    required this.clienteId,
    required this.nombreCliente,
    required this.direccionCliente,
    this.telefonoCliente,
    this.negocioCliente,
    this.rutaCliente,
    this.observacionesCliente,
    required this.fecha,
    required this.items,
    this.estado = 'pendiente',
    this.descuentoGlobal,
  });

  // Total sin ningún descuento
  double get subtotalSinDescuentos =>
      items.fold(0.0, (sum, item) => sum + item.subtotalSinDescuento);

  // Total con descuentos de items pero sin descuento global
  double get subtotalConDescuentosItems =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  // Total final con todos los descuentos (items + global)
  double get total {
    double subtotal = subtotalConDescuentosItems;
    if (descuentoGlobal != null && descuentoGlobal!.tieneDescuento) {
      subtotal = descuentoGlobal!.aplicarDescuento(subtotal);
    }
    return subtotal;
  }

  // Total de descuentos aplicados (items + global)
  double get totalDescuentos => subtotalSinDescuentos - total;

  // Descuento de items
  double get descuentoItems =>
      items.fold(0.0, (sum, item) => sum + item.montoDescuento);

  // Monto del descuento global
  double get montoDescuentoGlobal {
    if (descuentoGlobal != null && descuentoGlobal!.tieneDescuento) {
      return descuentoGlobal!.calcularDescuento(subtotalConDescuentosItems);
    }
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'direccionCliente': direccionCliente,
      'telefonoCliente': telefonoCliente,
      'negocioCliente': negocioCliente,
      'rutaCliente': rutaCliente,
      'observacionesCliente': observacionesCliente,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
      'total': total,
      'subtotalSinDescuentos': subtotalSinDescuentos,
      'totalDescuentos': totalDescuentos,
      'descuentoGlobal': descuentoGlobal?.toMap(),
    };
  }

  factory FacturaModel.fromMap(Map<String, dynamic> map, String docId, List<ItemFacturaModel> items) {
    return FacturaModel(
      id: docId,
      clienteId: map['clienteId'] as String,
      nombreCliente: map['nombreCliente'] as String,
      direccionCliente: map['direccionCliente'] as String,
      telefonoCliente: map['telefonoCliente'] as String?,
      negocioCliente: map['negocioCliente'] as String?,
      rutaCliente: map['rutaCliente'] as String?,
      observacionesCliente: map['observacionesCliente'] as String?,
      fecha: DateTime.parse(map['fecha'] as String),
      items: items,
      estado: map['estado'] as String? ?? 'pendiente',
      descuentoGlobal: map['descuentoGlobal'] != null
          ? DescuentoModel.fromMap(map['descuentoGlobal'] as Map<String, dynamic>)
          : null,
    );
  }

  FacturaModel copyWith({
    String? id,
    String? clienteId,
    String? nombreCliente,
    String? direccionCliente,
    String? telefonoCliente,
    String? negocioCliente,
    String? rutaCliente,
    String? observacionesCliente,
    DateTime? fecha,
    List<ItemFacturaModel>? items,
    String? estado,
    DescuentoModel? descuentoGlobal,
    bool eliminarDescuentoGlobal = false, // Para poder remover el descuento
  }) {
    return FacturaModel(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      direccionCliente: direccionCliente ?? this.direccionCliente,
      telefonoCliente: telefonoCliente ?? this.telefonoCliente,
      negocioCliente: negocioCliente ?? this.negocioCliente,
      rutaCliente: rutaCliente ?? this.rutaCliente,
      observacionesCliente: observacionesCliente ?? this.observacionesCliente,
      fecha: fecha ?? this.fecha,
      items: items ?? this.items,
      estado: estado ?? this.estado,
      descuentoGlobal: eliminarDescuentoGlobal ? null : (descuentoGlobal ?? this.descuentoGlobal),
    );
  }
}