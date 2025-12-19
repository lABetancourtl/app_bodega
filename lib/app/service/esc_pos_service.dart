import 'dart:typed_data';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/factura_model.dart';

enum BluetoothConnectionResult {
  success,
  deviceNotFound,
  connectionFailed,
  characteristicNotFound,
  permissionDenied,
  bluetoothOff,
  unknownError,
}

class EscPosService {
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _targetCharacteristic;
  static bool _isConnecting = false;
  static CapabilityProfile? _cachedProfile;


  static String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  static String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
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

  // <--- NUEVO: Método para cargar el perfil una sola vez --->
  static Future<CapabilityProfile> _getCapabilityProfile() async {
    if (_cachedProfile == null) {
      _cachedProfile = await CapabilityProfile.load();
    }
    return _cachedProfile!;
  }

  // --- Método para generar bytes ESC/POS (modificado para usar el perfil cacheado) ---
  static Future<List<int>> generarTicketEscPos(FacturaModel factura) async {
    final profile = await _getCapabilityProfile();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    final double total = factura.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final int totalUnidades = factura.items.fold(0, (sum, item) => sum + item.cantidadTotal);

    bytes += generator.reset();

    // ==================== NÚMERO Y FECHA ====================
    bytes += generator.row([
      PosColumn(
        text: _formatearFecha(factura.fecha),
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: '',
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
    ]);

    // ==================== ENCABEZADO ====================
    bytes += generator.text(
      'COMPROBANTE DE ENTREGA',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        bold: true,
      ),
    );
    bytes += generator.emptyLines(1);

    // ==================== INFORMACIÓN DEL CLIENTE ====================
    bytes += generator.text(
      'DATOS DEL CLIENTE',
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

    bytes += generator.hr(ch: '-');

    // ==================== PRODUCTOS ====================
    bytes += generator.text(
      'PRODUCTOS',
      styles: const PosStyles(
        align: PosAlign.left,
        bold: true,
      ),
    );

    bytes += generator.hr(ch: '-');

    bytes += generator.setStyles(const PosStyles(
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
      fontType: PosFontType.fontA,
      align: PosAlign.left,
    ));

    for (var item in factura.items) {
      const itemMainLeft = PosStyles(
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        fontType: PosFontType.fontA,
        align: PosAlign.left,
      );
      const itemMainRight = PosStyles(
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        fontType: PosFontType.fontA,
        align: PosAlign.right,
      );

      bytes += generator.row([
        PosColumn(
          text: '${item.cantidadTotal}',
          width: 2,
          styles: itemMainLeft,
        ),
        PosColumn(
          text: item.nombreProducto,
          width: 6,
          styles: itemMainLeft,
        ),
        PosColumn(
          text: '\$${_formatearPrecio(item.subtotal)}',
          width: 4,
          styles: itemMainRight,
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: '', width: 1),
        PosColumn(
          text: '@\$${_formatearPrecio(item.precioUnitario)} c/u',
          width: 11,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);

      if (item.tieneSabores && item.cantidadPorSabor.isNotEmpty) {
        final saboresTexto = item.cantidadPorSabor.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key}(${e.value})')
            .join(', ');

        if (saboresTexto.isNotEmpty) {
          bytes += generator.row([
            PosColumn(text: '', width: 1),
            PosColumn(
              text: saboresTexto,
              width: 11,
              styles: const PosStyles(
                fontType: PosFontType.fontA,
                height: PosTextSize.size1,
                width: PosTextSize.size1,
                align: PosAlign.left,
              ),
            ),
          ]);
        }
      }

      bytes += generator.emptyLines(1);
    }

    bytes += generator.hr(ch: '-');

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
        bold: false,
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

    // ==================== PIE DE PÁGINA ====================
    bytes += generator.text(
      'Gracias por su compra',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: false,
      ),
    );
    bytes += generator.text(
      'Novedades: 3105893020',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ==================== CORTE DE PAPEL ====================
    bytes += generator.cut();
    bytes += generator.emptyLines(1);

    return bytes;
  }

  // --- Métodos de conexión/envío (modificados) ---

  static Future<BluetoothConnectionResult> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) {
      return BluetoothConnectionResult.connectionFailed;
    }
    _isConnecting = true;

    try {
      if (_connectedDevice != null && _connectedDevice!.remoteId != device.remoteId) {
        await disconnectPrinter();
      }

      if (_connectedDevice != null && _connectedDevice!.remoteId == device.remoteId && _targetCharacteristic != null) {
        _isConnecting = false;
        return BluetoothConnectionResult.success;
      }

      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      await Future.delayed(const Duration(milliseconds: 500));

      List<BluetoothService> services = await device.discoverServices();

      BluetoothCharacteristic? foundCharacteristic;
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            foundCharacteristic = characteristic;
            break;
          }
        }
        if (foundCharacteristic != null) break;
      }

      if (foundCharacteristic == null) {
        await device.disconnect();
        _connectedDevice = null;
        _isConnecting = false;
        return BluetoothConnectionResult.characteristicNotFound;
      }

      _targetCharacteristic = foundCharacteristic;
      _isConnecting = false;
      return BluetoothConnectionResult.success;

    } on FlutterBluePlusException catch (e) {
      print('Error de FlutterBluePlus al conectar: ${e.code} - ${e.description}'); // Usar .description
      _connectedDevice = null;
      _targetCharacteristic = null;
      _isConnecting = false;
      return BluetoothConnectionResult.connectionFailed;
    } catch (e) {
      print('Error inesperado al conectar: $e');
      _connectedDevice = null;
      _targetCharacteristic = null;
      _isConnecting = false;
      return BluetoothConnectionResult.unknownError;
    }
  }

  /// Envía los bytes ESC/POS a la impresora ya conectada.
  /// NO incluye la pausa de 2 segundos al final.
  static Future<BluetoothConnectionResult> sendPrintData(List<int> bytes) async {
    if (_connectedDevice == null || _targetCharacteristic == null) {
      return BluetoothConnectionResult.connectionFailed;
    }

    try {
      const int chunkSize = 20;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);

        await _targetCharacteristic!.write(chunk, withoutResponse: true);
        // Esta pausa entre chunks es importante para evitar saturar el buffer de la impresora.
        // Puedes experimentar con reducirla (e.g., 20ms, 10ms) si tu impresora es rápida.
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // <--- ELIMINADO: await Future.delayed(const Duration(seconds: 2)); --->
      // Esta pausa se manejará UNA SOLA VEZ al final de TODAS las impresiones en el UI.

      return BluetoothConnectionResult.success;
    } on FlutterBluePlusException catch (e) {
      print('Error de FlutterBluePlus al enviar datos: ${e.code} - ${e.description}'); // Usar .description
      return BluetoothConnectionResult.connectionFailed;
    } catch (e) {
      print('Error inesperado al enviar datos: $e');
      return BluetoothConnectionResult.unknownError;
    }
  }

  static Future<void> disconnectPrinter() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        print('Error al desconectar impresora: $e');
      } finally {
        _connectedDevice = null;
        _targetCharacteristic = null;
        _isConnecting = false;
      }
    }
  }

  static bool isPrinterConnected() {
    return _connectedDevice != null && _targetCharacteristic != null;
  }

  // --- El método imprimirTicketBluetoothConDispositivo ya no se usará directamente para el bucle ---
  // Lo mantengo por si lo usas en otro lugar para una sola factura, pero para el bucle de 50 facturas,
  // la lógica se moverá al método _imprimirTodasLasFacturas.
  static Future<void> imprimirTicketBluetoothConDispositivo(
      FacturaModel factura,
      BluetoothDevice device,
      ) async {
    if (_connectedDevice?.remoteId != device.remoteId || !isPrinterConnected()) {
      final connectResult = await connectToDevice(device);
      if (connectResult != BluetoothConnectionResult.success) {
        throw Exception('Error al conectar con la impresora: ${connectResult.name}');
      }
    }

    final bytes = await generarTicketEscPos(factura);
    final printResult = await sendPrintData(bytes);

    if (printResult != BluetoothConnectionResult.success) {
      throw Exception('Error al enviar datos a la impresora: ${printResult.name}');
    }
    // Para una sola factura, sí podríamos añadir una pausa final aquí si es necesario
    await Future.delayed(const Duration(seconds: 2)); // Pausa para el corte final
  }

  // --- Otros métodos (sin cambios) ---

  /// Solicitar permisos de Bluetooth
  static Future<bool> solicitarPermisosBluetooth() async {
    // ... tu implementación actual ...
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
    // ... tu implementación actual ...
    try {
      bool permisosOtorgados = await solicitarPermisosBluetooth();
      if (!permisosOtorgados) {
        throw 'Permisos de Bluetooth denegados. Por favor, actívalos en la configuración de la app.';
      }

      List<BluetoothDevice> impresoras = [];

      if (await FlutterBluePlus.isSupported == false) {
        throw 'Bluetooth no está soportado en este dispositivo';
      }

      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        throw 'Por favor, enciende el Bluetooth en tu dispositivo';
      }

      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;

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

      const double mmToPt = 2.83465;
      const double pageWidth = 80 * mmToPt;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, double.infinity),
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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

                pw.Text(
                  _formatearFecha(factura.fecha),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text (
                  'No: ${factura.id ?? '0000'}',
                  style: pw.TextStyle(
                    fontSize: 10,
                  ),
                ),

                pw.Divider(),

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
                      if (item.tieneSabores && item.cantidadPorSabor.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 20),
                          child: pw.Text(
                            item.cantidadPorSabor.entries
                                .where((e) => e.value > 0)
                                .map((e) => '${e.key}(${e.value})')
                                .join(', '),
                            style: const pw.TextStyle(fontSize: 8, ),
                          ),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 20),
                        child: pw.Text(
                          '@\$${_formatearPrecio(item.precioUnitario)} c/u',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }).toList(),

                pw.Divider(thickness: 2),

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

                if (factura.observacionesCliente != null && factura.observacionesCliente!.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'NOTAS:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(factura.observacionesCliente!, style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 8),
                ],

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
    // ... tu implementación actual ...
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
    // ... tu implementación actual ...
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
    buffer.writeln('-' * ancho);
    buffer.writeln(_centrar('Gracias por su compra', ancho));
    buffer.writeln(_centrar('Novedades: 3105893020', ancho));
    buffer.writeln();
    buffer.writeln(_centrar('Bodega App v1.0', ancho));
    buffer.writeln();

    return buffer.toString();
  }


  // Agregar este método a la clase EscPosService en esc_pos_service.dart

  /// Genera bytes ESC/POS para el resumen de productos del día
  static Future<List<int>> generarResumenProductosEscPos(
      DateTime fecha,
      Map<String, Map<String, dynamic>> resumenProductos,
      int totalFacturas,
      ) async {
    final profile = await _getCapabilityProfile();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Calcular totales
    final productos = resumenProductos.entries.toList();
    productos.sort((a, b) => (b.value['cantidadTotal'] as int).compareTo(a.value['cantidadTotal'] as int));

    final totalGeneral = productos.fold(0.0, (sum, p) => sum + (p.value['subtotal'] as double));
    final cantidadTotalProductos = productos.fold(0, (sum, p) => sum + (p.value['cantidadTotal'] as int));

    bytes += generator.reset();

    // ==================== FECHA ====================
    bytes += generator.text(
      _formatearFecha(fecha),
      styles: const PosStyles(
        align: PosAlign.left,
        bold: true,
      ),
    );
    bytes += generator.emptyLines(1);

    // ==================== ENCABEZADO ====================
    bytes += generator.text(
      'RESUMEN DE PRODUCTOS',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        bold: true,
      ),
    );
    bytes += generator.emptyLines(1);

    // ==================== INFORMACIÓN GENERAL ====================
    bytes += generator.row([
      PosColumn(
        text: 'Facturas:',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: '$totalFacturas',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: 'Total Productos:',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: '$cantidadTotalProductos',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr(ch: '-');

    // ==================== LISTA DE PRODUCTOS ====================
    bytes += generator.text(
      'DETALLE',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.hr(ch: '-');

    for (var producto in productos) {
      final datos = producto.value;
      final nombreProducto = datos['nombreProducto'] as String;
      final cantidadTotal = datos['cantidadTotal'] as int;
      final precioUnitario = datos['precioUnitario'] as double;
      final subtotal = datos['subtotal'] as double;
      final tieneSabores = datos['tieneSabores'] as bool;
      final sabores = datos['sabores'] as Map<String, int>;

      // Nombre y cantidad
      bytes += generator.row([
        PosColumn(
          text: '$cantidadTotal',
          width: 2,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: nombreProducto,
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '\$${_formatearPrecio(subtotal)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      // Precio unitario
      bytes += generator.row([
        PosColumn(text: '', width: 1),
        PosColumn(
          text: '@\$${_formatearPrecio(precioUnitario)} c/u',
          width: 11,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            align: PosAlign.left,
          ),
        ),
      ]);

      // Sabores si aplica
      if (tieneSabores && sabores.isNotEmpty) {
        bytes += generator.row([
          PosColumn(text: '', width: 1),
          PosColumn(
            text: 'Sabores:',
            width: 11,
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              bold: true,
            ),
          ),
        ]);

        for (var saborEntry in sabores.entries) {
          if (saborEntry.value > 0) {
            bytes += generator.row([
              PosColumn(text: '', width: 2),
              PosColumn(
                text: '${saborEntry.key}:',
                width: 7,
                styles: const PosStyles(fontType: PosFontType.fontB),
              ),
              PosColumn(
                text: '${saborEntry.value}',
                width: 3,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.right,
                ),
              ),
            ]);
          }
        }
      }

      bytes += generator.emptyLines(1);
    }

    bytes += generator.hr(ch: '-');

    // ==================== TOTAL ====================
    bytes += generator.text(
      'TOTAL GENERAL',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      '\$${_formatearPrecio(totalGeneral)}',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );

    bytes += generator.emptyLines(1);
    // ==================== CORTE DE PAPEL ====================
    bytes += generator.cut();
    bytes += generator.emptyLines(1);

    return bytes;
  }
}