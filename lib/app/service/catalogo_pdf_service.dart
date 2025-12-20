import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:http/http.dart' as http;

class CatalogoPdfService {
  /// Genera un PDF del catálogo completo de productos
  static Future<File> generarCatalogoPDF({
    required List<CategoriaModel> categorias,
    required Map<String, List<ProductoModel>> productosPorCategoria,
    String? nombreNegocio,
    String? telefonoContacto,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final fechaFormateada = DateFormat('dd/MM/yyyy').format(ahora);

    // Páginas de productos por categoría (sin portada)
    for (var categoria in categorias) {
      final productos = productosPorCategoria[categoria.id] ?? [];
      if (productos.isEmpty) continue;

      await _agregarPaginasCategoria(
        pdf: pdf,
        categoria: categoria,
        productos: productos,
      );
    }

    // Guardar PDF
    final output = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(ahora);
    final file = File('${output.path}/catalogo_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static Future<void> _agregarPaginasCategoria({
    required pw.Document pdf,
    required CategoriaModel categoria,
    required List<ProductoModel> productos,
  }) async {
    // 5 productos por página (optimizado)
    const productosPorPagina = 5;

    for (var i = 0; i < productos.length; i += productosPorPagina) {
      final productosEnPagina = productos.skip(i).take(productosPorPagina).toList();

      // Pre-cargar los widgets de productos
      final productosWidgets = await Future.wait(
        productosEnPagina.map((producto) => _buildProductoItem(producto: producto)),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header de categoría (más compacto)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1976D2'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      categoria.nombre.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Pág. ${(i ~/ productosPorPagina) + 1}/${(productos.length / productosPorPagina).ceil()}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Lista de productos (más compacta)
              ...productosWidgets.map((widget) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: widget,
              )),

              pw.Spacer(),

              // Footer (más pequeño)
              pw.Divider(color: PdfColors.grey300, height: 10),
              pw.Text(
                'Catálogo de Productos - ${categoria.nombre}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  static Future<pw.Widget> _buildProductoItem({
    required ProductoModel producto,
  }) async {
    pw.ImageProvider? imageProvider;

    // Cargar imagen si existe
    if (producto.imagenPath != null && producto.imagenPath!.isNotEmpty) {
      try {
        if (producto.imagenPath!.startsWith('http')) {
          final response = await http.get(Uri.parse(producto.imagenPath!));
          if (response.statusCode == 200) {
            imageProvider = pw.MemoryImage(response.bodyBytes);
          }
        } else {
          final file = File(producto.imagenPath!);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            imageProvider = pw.MemoryImage(bytes);
          }
        }
      } catch (e) {
        print('Error cargando imagen: $e');
      }
    }

    return pw.Container(
      height: 110, // Altura fija optimizada
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Imagen del producto (más compacta)
          pw.Container(
            width: 110,
            height: 110,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F5F5F5'),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                bottomLeft: pw.Radius.circular(6),
              ),
            ),
            child: imageProvider != null
                ? pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(
                imageProvider,
                fit: pw.BoxFit.cover,
                width: 110,
                height: 110,
              ),
            )
                : pw.Center(
              child: pw.Icon(
                pw.IconData(0xe547),
                size: 35,
                color: PdfColors.grey400,
              ),
            ),
          ),

          // Información del producto (más compacta)
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Nombre del producto (más compacto)
                  pw.Text(
                    producto.nombre,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    maxLines: 2,
                  ),
                  pw.SizedBox(height: 4),

                  // Sabores (más pequeños)
                  if (producto.sabores.isNotEmpty) ...[
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 3,
                          height: 3,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#1976D2'),
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          child: pw.Text(
                            producto.sabores.join(', '),
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                  ],

                  // Precio (optimizado)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PRECIO',
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '\$${_formatearPrecio(producto.precio)}',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#FF6B35'),
                            ),
                          ),
                        ],
                      ),
                      if (producto.cantidadPorPaca != null)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#E3F2FD'),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                '${producto.cantidadPorPaca}',
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#1976D2'),
                                ),
                              ),
                              pw.Text(
                                'x paca',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor.fromHex('#1976D2'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  /// Comparte el PDF generado
  static Future<void> compartirPDF(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Catálogo de Productos',
      text: 'Te comparto nuestro catálogo de productos actualizado.',
    );
  }
}