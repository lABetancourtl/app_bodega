import 'dart:typed_data';
import 'dart:io';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class EscPosService {
  static String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  static String _formatearFecha(DateTime fecha) {
    // Agregar un día a la fecha
    final fechaMasUnDia = fecha.add(const Duration(days: 1));

    return '${fechaMasUnDia.day.toString().padLeft(2, '0')}/'
        '${fechaMasUnDia.month.toString().padLeft(2, '0')}/'
        '${fechaMasUnDia.year}';
  }

  static String _formatearHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  static String _centrar(String texto, int ancho) {
    if (texto.length >= ancho) return texto;
    final espacios = (ancho - texto.length) ~/ 2;
    return ' ' * espacios + texto;
  }

  static String _alinearDerecha(String texto, int ancho) {
    if (texto.length >= ancho) return texto;
    final espacios = ancho - texto.length;
    return ' ' * espacios + texto;
  }

  static String _formatearLinea(String izquierda, String derecha, int ancho) {
    final espacios = ancho - izquierda.length - derecha.length;
    if (espacios < 1) return '$izquierda $derecha';
    return izquierda + (' ' * espacios) + derecha;
  }

  static Future<List<int>> generarTicketEscPos(FacturaModel factura) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    final double total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final int totalUnidades = factura.items.fold(0, (sum, item) => sum + item.cantidadTotal);

    // ==================== ENCABEZADO ====================
    bytes += generator.text(
      'BODEGA',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );

    bytes += generator.text(
      'COMPROBANTE DE ENTREGA',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.hr(ch: '=');
    bytes += generator.emptyLines(1);

    // ==================== NÚMERO Y FECHA ====================
    bytes += generator.row([
      PosColumn(
        text: 'No: ${factura.id ?? '0000'}',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.left),
      ),
      PosColumn(
        text: _formatearFecha(factura.fecha),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.text(
      'Hora: ${_formatearHora(factura.fecha)}',
      styles: const PosStyles(align: PosAlign.right),
    );

    bytes += generator.hr(ch: '-');

    // ==================== INFORMACIÓN DEL CLIENTE ====================
    bytes += generator.text(
      'CLIENTE',
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text('Nombre: ${factura.nombreCliente}');

    if (factura.negocioCliente != null && factura.negocioCliente!.isNotEmpty) {
      bytes += generator.text('Negocio: ${factura.negocioCliente}');
    }

    if (factura.direccionCliente != null && factura.direccionCliente!.isNotEmpty) {
      bytes += generator.text('Direccion: ${factura.direccionCliente}');
    }

    if (factura.telefonoCliente != null && factura.telefonoCliente!.isNotEmpty) {
      bytes += generator.text('Telefono: ${factura.telefonoCliente}');
    }

    if (factura.rutaCliente != null && factura.rutaCliente!.isNotEmpty) {
      bytes += generator.text('Ruta: ${factura.rutaCliente}');
    }

    bytes += generator.hr(ch: '=');

    // ==================== PRODUCTOS ====================
    bytes += generator.text(
      'PRODUCTOS',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.hr(ch: '-');

    // Encabezado de tabla
    bytes += generator.row([
      PosColumn(text: 'CANT', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(text: 'PRODUCTO', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'TOTAL',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr(ch: '-');

    // Items de productos
    for (var item in factura.items) {
      bytes += generator.row([
        PosColumn(text: '${item.cantidadTotal}', width: 2),
        PosColumn(text: item.nombreProducto, width: 6),
        PosColumn(
          text: '\$${_formatearPrecio(item.subtotal)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: '', width: 2),
        PosColumn(
          text: '@\$${_formatearPrecio(item.precioUnitario)} c/u',
          width: 10,
          styles: const PosStyles(fontType: PosFontType.fontB),
        ),
      ]);

      if (item.tieneSabores && item.cantidadPorSabor.isNotEmpty) {
        final saboresTexto = item.cantidadPorSabor.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key}(${e.value})')
            .join(', ');

        if (saboresTexto.isNotEmpty) {
          bytes += generator.row([
            PosColumn(text: '', width: 2),
            PosColumn(
              text: saboresTexto,
              width: 10,
              styles: const PosStyles(fontType: PosFontType.fontB),
            ),
          ]);
        }
      }

      bytes += generator.emptyLines(1);
    }

    bytes += generator.hr(ch: '=');

    // ==================== RESUMEN ====================
    bytes += generator.row([
      PosColumn(
        text: 'Total unidades:',
        width: 8,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: '$totalUnidades',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.emptyLines(1);

    // ==================== TOTAL ====================
    bytes += generator.text(
      'TOTAL A PAGAR',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      '\$${_formatearPrecio(total)}',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );

    bytes += generator.hr(ch: '=');

    // ==================== OBSERVACIONES ====================
    if (factura.observacionesCliente != null && factura.observacionesCliente!.isNotEmpty) {
      bytes += generator.emptyLines(1);
      bytes += generator.text(
        'NOTAS:',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(factura.observacionesCliente!);
      bytes += generator.emptyLines(1);
    }

    // ==================== FIRMA ====================
    bytes += generator.emptyLines(2);
    bytes += generator.text(
      '_________________________',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Firma del Cliente',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // ==================== PIE DE PÁGINA ====================
    bytes += generator.hr(ch: '-');
    bytes += generator.text(
      'Gracias por su compra',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.text(
      'Novedades: 3105893020',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Bodega App v1.0',
      styles: const PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontB,
      ),
    );

    // ==================== CORTE DE PAPEL ====================
    bytes += generator.emptyLines(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Imprimir por Bluetooth usando flutter_blue_plus
  static Future<void> imprimirTicketBluetooth(FacturaModel factura) async {
    try {
      final bytes = await generarTicketEscPos(factura);

      // Implementación con flutter_blue_plus
      // Nota: Debes importar: import 'package:flutter_blue_plus/flutter_blue_plus.dart';

      throw UnimplementedError(
          'Debes implementar la selección de impresora Bluetooth. '
              'Ver método imprimirTicketBluetoothConDispositivo()'
      );
    } catch (e) {
      throw Exception('Error al imprimir por Bluetooth: $e');
    }
  }

  /// Imprimir por Bluetooth con dispositivo específico
  static Future<void> imprimirTicketBluetoothConDispositivo(
      FacturaModel factura,
      BluetoothDevice device,
      ) async {
    try {
      final bytes = await generarTicketEscPos(factura);

      // Conectar al dispositivo
      await device.connect(timeout: const Duration(seconds: 10));

      // Esperar a que esté completamente conectado
      await Future.delayed(const Duration(milliseconds: 500));

      // Descubrir servicios
      List<BluetoothService> services = await device.discoverServices();

      // Buscar el servicio de impresión (generalmente el primero)
      BluetoothCharacteristic? targetCharacteristic;

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) break;
      }

      if (targetCharacteristic == null) {
        throw 'No se encontró una característica de escritura en la impresora';
      }

      // Enviar datos en chunks de 20 bytes (máximo MTU típico)
      const int chunkSize = 20;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);

        await targetCharacteristic.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 50)); // Pequeña pausa entre chunks
      }

      // Esperar a que se complete la impresión
      await Future.delayed(const Duration(seconds: 1));

      // Desconectar
      await device.disconnect();

    } catch (e) {
      throw Exception('Error al imprimir por Bluetooth: $e');
    }
  }

  /// Solicitar permisos de Bluetooth
  static Future<bool> solicitarPermisosBluetooth() async {
    if (!Platform.isAndroid) {
      return true; // iOS maneja permisos automáticamente
    }

    try {
      // Para Android 12+ (API 31+)
      if (await Permission.bluetoothScan.isDenied) {
        final status = await Permission.bluetoothScan.request();
        if (!status.isGranted) return false;
      }

      if (await Permission.bluetoothConnect.isDenied) {
        final status = await Permission.bluetoothConnect.request();
        if (!status.isGranted) return false;
      }

      // Para versiones anteriores de Android
      if (await Permission.location.isDenied) {
        final status = await Permission.location.request();
        if (!status.isGranted) return false;
      }

      return true;
    } catch (e) {
      throw Exception('Error al solicitar permisos: $e');
    }
  }

  /// Escanear impresoras Bluetooth disponibles
  static Future<List<BluetoothDevice>> escanearImpresorasBluetooth() async {
    try {
      // 1. SOLICITAR PERMISOS PRIMERO
      bool permisosOtorgados = await solicitarPermisosBluetooth();
      if (!permisosOtorgados) {
        throw 'Permisos de Bluetooth denegados. Por favor, actívalos en la configuración de la app.';
      }

      List<BluetoothDevice> impresoras = [];

      // 2. Verificar si Bluetooth está disponible
      if (await FlutterBluePlus.isSupported == false) {
        throw 'Bluetooth no está soportado en este dispositivo';
      }

      // 3. Verificar si Bluetooth está encendido
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        throw 'Por favor, enciende el Bluetooth en tu dispositivo';
      }

      // 4. Obtener dispositivos ya vinculados (más rápido)
      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;

      // 5. Filtrar por impresoras (nombres típicos de impresoras térmicas)
      for (var device in bondedDevices) {
        String name = device.platformName.toLowerCase();
        if (name.contains('printer') ||
            name.contains('pos') ||
            name.contains('bluetooth printer') ||
            name.contains('rp') ||
            name.contains('mtp') ||
            name.contains('thermal')) {
          impresoras.add(device);
        }
      }

      // 6. Si no hay dispositivos vinculados, escanear
      if (impresoras.isEmpty) {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

        var subscription = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult result in results) {
            String name = result.device.platformName.toLowerCase();
            if ((name.contains('printer') ||
                name.contains('pos') ||
                name.contains('bluetooth printer') ||
                name.contains('rp') ||
                name.contains('mtp') ||
                name.contains('thermal')) &&
                !impresoras.contains(result.device)) {
              impresoras.add(result.device);
            }
          }
        });

        await Future.delayed(const Duration(seconds: 4));
        await subscription.cancel();
        await FlutterBluePlus.stopScan();
      }

      return impresoras;
    } catch (e) {
      throw Exception('Error al escanear impresoras: $e');
    }
  }

  /// Generar PDF con formato de ticket 80mm
  static Future<void> descargarTicketPDF(FacturaModel factura) async {
    try {
      final pdf = pw.Document();
      final double total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);
      final int totalUnidades = factura.items.fold(0, (sum, item) => sum + item.cantidadTotal);

      // Tamaño de papel 80mm (aprox 3.15 pulgadas)
      const double mmToPt = 2.83465;
      const double pageWidth = 80 * mmToPt; // 80mm

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, double.infinity),
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ==================== ENCABEZADO ====================
                pw.Center(
                  child: pw.Text(
                    'BODEGA',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'COMPROBANTE DE ENTREGA',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 8),

                // ==================== NÚMERO Y FECHA ====================
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'No: ${factura.id ?? '0000'}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _formatearFecha(factura.fecha),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Hora: ${_formatearHora(factura.fecha)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Divider(),

                // ==================== INFORMACIÓN DEL CLIENTE ====================
                pw.Text(
                  'CLIENTE',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Nombre: ${factura.nombreCliente}', style: const pw.TextStyle(fontSize: 9)),
                if (factura.negocioCliente != null && factura.negocioCliente!.isNotEmpty)
                  pw.Text('Negocio: ${factura.negocioCliente}', style: const pw.TextStyle(fontSize: 9)),
                if (factura.direccionCliente != null && factura.direccionCliente!.isNotEmpty)
                  pw.Text('Direccion: ${factura.direccionCliente}', style: const pw.TextStyle(fontSize: 9)),
                if (factura.telefonoCliente != null && factura.telefonoCliente!.isNotEmpty)
                  pw.Text('Telefono: ${factura.telefonoCliente}', style: const pw.TextStyle(fontSize: 9)),
                if (factura.rutaCliente != null && factura.rutaCliente!.isNotEmpty)
                  pw.Text('Ruta: ${factura.rutaCliente}', style: const pw.TextStyle(fontSize: 9)),
                pw.Divider(thickness: 2),

                // ==================== PRODUCTOS ====================
                pw.Center(
                  child: pw.Text(
                    'PRODUCTOS',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Divider(),

                // Encabezado de tabla
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('CANT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 6,
                      child: pw.Text('PRODUCTO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                pw.Divider(),

                // Items de productos
                ...factura.items.map((item) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('${item.cantidadTotal}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Expanded(
                            flex: 6,
                            child: pw.Text(item.nombreProducto, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('\$${_formatearPrecio(item.subtotal)}', style: const pw.TextStyle(fontSize: 9)),
                            ),
                          ),
                        ],
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 20),
                        child: pw.Text(
                          '@\$${_formatearPrecio(item.precioUnitario)} c/u',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ),
                      if (item.tieneSabores && item.cantidadPorSabor.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 20),
                          child: pw.Text(
                            item.cantidadPorSabor.entries
                                .where((e) => e.value > 0)
                                .map((e) => '${e.key}(${e.value})')
                                .join(', '),
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }).toList(),

                pw.Divider(thickness: 2),

                // ==================== RESUMEN ====================
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total unidades:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '$totalUnidades',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // ==================== TOTAL ====================
                pw.Center(
                  child: pw.Text(
                    'TOTAL A PAGAR',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    '\$${_formatearPrecio(total)}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Divider(thickness: 2),

                // ==================== OBSERVACIONES ====================
                if (factura.observacionesCliente != null && factura.observacionesCliente!.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'NOTAS:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(factura.observacionesCliente!, style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 8),
                ],

                // ==================== FIRMA ====================
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide()),
                        ),
                        child: pw.SizedBox(height: 1),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma del Cliente', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // ==================== PIE DE PÁGINA ====================
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Gracias por su compra',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Novedades: 3105893020',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Bodega App v1.0',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Guardar y compartir el PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Factura_${factura.id ?? 'nueva'}.pdf',
      );
    } catch (e) {
      throw Exception('Error al generar PDF: $e');
    }
  }

  /// Imprimir por WiFi
  static Future<void> imprimirTicketWifi(FacturaModel factura, String ip) async {
    try {
      final bytes = await generarTicketEscPos(factura);

      final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
      final PosPrintResult res = await printer.connect(ip, port: 9100);

      if (res != PosPrintResult.success) {
        throw 'No se pudo conectar a la impresora LAN';
      }

      printer.rawBytes(Uint8List.fromList(bytes));
      printer.disconnect();
    } catch (e) {
      throw Exception('Error al imprimir por WiFi: $e');
    }
  }

  /// Generar vista previa del ticket en formato texto
  static String generarVistaPrevia(FacturaModel factura) {
    final StringBuffer buffer = StringBuffer();
    final double total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final int totalUnidades = factura.items.fold(0, (sum, item) => sum + item.cantidadTotal);
    const int ancho = 48;

    buffer.writeln(_centrar('DISTRIBUIDORA', ancho));
    buffer.writeln(_centrar('COMPROBANTE DE ENTREGA', ancho));
    buffer.writeln('=' * ancho);
    buffer.writeln();

    buffer.writeln(_formatearLinea(
      'No: ${factura.id ?? '0000'}',
      _formatearFecha(factura.fecha),
      ancho,
    ));
    buffer.writeln(_alinearDerecha('Hora: ${_formatearHora(factura.fecha)}', ancho));
    buffer.writeln('-' * ancho);

    buffer.writeln('CLIENTE');
    buffer.writeln('Nombre: ${factura.nombreCliente}');
    if (factura.negocioCliente != null && factura.negocioCliente!.isNotEmpty) {
      buffer.writeln('Negocio: ${factura.negocioCliente}');
    }
    if (factura.direccionCliente != null && factura.direccionCliente!.isNotEmpty) {
      buffer.writeln('Direccion: ${factura.direccionCliente}');
    }
    if (factura.telefonoCliente != null && factura.telefonoCliente!.isNotEmpty) {
      buffer.writeln('Telefono: ${factura.telefonoCliente}');
    }
    if (factura.rutaCliente != null && factura.rutaCliente!.isNotEmpty) {
      buffer.writeln('Ruta: ${factura.rutaCliente}');
    }
    buffer.writeln('=' * ancho);

    buffer.writeln(_centrar('PRODUCTOS', ancho));
    buffer.writeln('-' * ancho);
    buffer.writeln('CANT  PRODUCTO                      TOTAL');
    buffer.writeln('-' * ancho);

    for (var item in factura.items) {
      final cant = '${item.cantidadTotal}'.padRight(4);
      final nombre = item.nombreProducto.length > 24
          ? item.nombreProducto.substring(0, 24)
          : item.nombreProducto.padRight(24);
      final precio = '\$${_formatearPrecio(item.subtotal)}'.padLeft(12);

      buffer.writeln('$cant  $nombre$precio');
      buffer.writeln('      @\$${_formatearPrecio(item.precioUnitario)} c/u');

      if (item.tieneSabores && item.cantidadPorSabor.isNotEmpty) {
        final saboresTexto = item.cantidadPorSabor.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key}(${e.value})')
            .join(', ');
        if (saboresTexto.isNotEmpty) {
          buffer.writeln('      $saboresTexto');
        }
      }
      buffer.writeln();
    }

    buffer.writeln('=' * ancho);
    buffer.writeln(_formatearLinea('Total unidades:', '$totalUnidades', ancho));
    buffer.writeln();
    buffer.writeln(_centrar('TOTAL A PAGAR', ancho));
    buffer.writeln(_centrar('\$${_formatearPrecio(total)}', ancho));
    buffer.writeln('=' * ancho);

    if (factura.observacionesCliente != null && factura.observacionesCliente!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('NOTAS:');
      buffer.writeln(factura.observacionesCliente);
      buffer.writeln();
    }

    buffer.writeln();
    buffer.writeln();
    buffer.writeln(_centrar('_________________________', ancho));
    buffer.writeln(_centrar('Firma del Cliente', ancho));
    buffer.writeln();
    buffer.writeln('-' * ancho);
    buffer.writeln(_centrar('Gracias por su compra', ancho));
    buffer.writeln(_centrar('Novedades: 3105893020', ancho));
    buffer.writeln();
    buffer.writeln(_centrar('Bodega App v1.0', ancho));
    buffer.writeln();

    return buffer.toString();
  }
}