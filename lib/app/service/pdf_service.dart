import 'package:app_bodega/app/model/factura_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  static Future<void> generarYDescargarPDF(FacturaModel factura) async {
    final pdf = pw.Document();

    double total = factura.items.fold(0, (sum, item) => sum + item.subtotal);

    final fechaFormato = '${factura.fecha.day.toString().padLeft(2, '0')}/'
        '${factura.fecha.month.toString().padLeft(2, '0')}/'
        '${factura.fecha.year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado profesional
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'FACTURA DE VENTA',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      height: 0.5,
                      color: PdfColors.black,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Información de la factura
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Factura #: ${factura.id ?? 'Nuevo'}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Fecha: $fechaFormato',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Información del cliente
              pw.Text(
                'INFORMACIÓN DEL CLIENTE',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                padding: pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Nombre: ${factura.nombreCliente}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Negocio: ${factura.negocioCliente ?? 'N/A'}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Dirección: ${factura.direccionCliente ?? 'N/A'}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    if (factura.rutaCliente != null)
                      pw.Text(
                        'Ruta: ${factura.rutaCliente}',
                        style: pw.TextStyle(fontSize: 8),
                      ),
                    if (factura.observacionesCliente != null && factura.observacionesCliente!.isNotEmpty)
                      pw.Text(
                        'Obs: ${factura.observacionesCliente}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Tabla de productos
              pw.Text(
                'DETALLE DE PRODUCTOS',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  // Encabezado tabla
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'PRODUCTO',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'CANT',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'V.UNIT',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'SUBTOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Items
                  ...factura.items.map((item) {
                    String sabores = '';
                    if (item.tieneSabores) {
                      sabores = item.cantidadPorSabor.entries
                          .where((e) => e.value > 0)
                          .map((e) => '${e.key}(${e.value})')
                          .join(' ');
                    }

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.nombreProducto,
                                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                              ),
                              if (sabores.isNotEmpty)
                                pw.Text(
                                  sabores,
                                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                                ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '${item.cantidadTotal}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '\$${_formatearPrecio(item.precioUnitario)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '\$${_formatearPrecio(item.subtotal)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 8),

              // Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: pw.EdgeInsets.only(right: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 60,
                      height: 0.5,
                      color: PdfColors.black,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'TOTAL: \$${_formatearPrecio(total)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Container(
                      width: 60,
                      height: 0.5,
                      color: PdfColors.black,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Pie de página
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: 0.5,
                      color: PdfColors.grey,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '¡Gracias por su compra!',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Novedades, comuniquese al 3105893020',
                      style: pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Descargar o imprimir
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}