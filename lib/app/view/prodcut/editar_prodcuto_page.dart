import 'dart:io';

import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:app_bodega/app/service/cloudinary_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_bodega/app/view/barcode/barcode_scaner_page.dart';

// ============= COLORES DEL TEMA =============
class AppColors {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2E5077);
  static const Color accent = Color(0xFF00B894);
  static const Color accentLight = Color(0xFFE8F8F5);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class EditarProductoPage extends StatefulWidget {
  final ProductoModel producto;
  final List<CategoriaModel> categorias;

  const EditarProductoPage({
    super.key,
    required this.producto,
    required this.categorias,
  });

  @override
  State<EditarProductoPage> createState() => _EditarProductoPageState();
}

class _EditarProductoPageState extends State<EditarProductoPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryHelper _cloudinaryHelper = CloudinaryHelper();

  late TextEditingController _nombreController;
  late TextEditingController _precioController;
  late TextEditingController _cantidadPacaController;

  late CategoriaModel _categoriaSeleccionada;
  late List<TextEditingController> _saborControllers;
  File? _imagenSeleccionada;
  bool _subiendoImagen = false;
  String? _imagenActual;
  Map<String, String> _codigosPorSabor = {};

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.producto.nombre);
    _precioController = TextEditingController(text: widget.producto.precio.toString());
    _cantidadPacaController = TextEditingController(
      text: widget.producto.cantidadPorPaca?.toString() ?? '',
    );
    _categoriaSeleccionada = widget.categorias.firstWhere(
          (c) => c.id == widget.producto.categoriaId,
    );
    _saborControllers = widget.producto.sabores
        .map((sabor) => TextEditingController(text: sabor))
        .toList();

    if (widget.producto.imagenPath != null && widget.producto.imagenPath!.startsWith('http')) {
      _imagenActual = widget.producto.imagenPath;
    }

    if (widget.producto.codigosPorSabor != null) {
      _codigosPorSabor = Map<String, String>.from(widget.producto.codigosPorSabor!);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _cantidadPacaController.dispose();
    for (var controller in _saborControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _mostrarSnackBar(String mensaje, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : (isError ? Icons.error : Icons.info),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.accent : (isError ? AppColors.error : AppColors.primary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _agregarSabor() {
    setState(() {
      _saborControllers.add(TextEditingController());
    });
  }

  void _eliminarSabor(int index) {
    final sabor = _saborControllers[index].text.trim();
    if (sabor.isNotEmpty && _codigosPorSabor.containsKey(sabor)) {
      _codigosPorSabor.remove(sabor);
    }

    setState(() {
      _saborControllers[index].dispose();
      _saborControllers.removeAt(index);
    });
  }

  Future<void> _tomarFoto() async {
    try {
      final XFile? foto = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (foto != null) {
        setState(() {
          _imagenSeleccionada = File(foto.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error al tomar la foto', isError: true);
      }
    }
  }

  Future<void> _seleccionarDelGalerista() async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (imagen != null) {
        setState(() {
          _imagenSeleccionada = File(imagen.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error al seleccionar la imagen', isError: true);
      }
    }
  }

  Future<void> _escanearCodigoParaSabor(String sabor) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerPage(),
      ),
    );

    if (resultado != null && resultado is String) {
      setState(() {
        _codigosPorSabor[sabor] = resultado;
      });

      if (mounted) {
        _mostrarSnackBar('Código "$resultado" asignado a sabor "$sabor"', isSuccess: true);
      }
    }
  }

  void _gestionarCodigosBarras() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Códigos de Barras por Sabor',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Asigna códigos únicos a cada sabor',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  if (_saborControllers.isEmpty || _saborControllers.every((c) => c.text.trim().isEmpty))
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            const Text(
                              'Primero agrega sabores al producto',
                              style: TextStyle(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: _saborControllers.asMap().entries.map((entry) {
                        final controller = entry.value;
                        final sabor = controller.text.trim();

                        if (sabor.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final tieneCodigo = _codigosPorSabor.containsKey(sabor);
                        final codigo = _codigosPorSabor[sabor];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tieneCodigo ? AppColors.accent : AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tieneCodigo ? AppColors.accent : AppColors.textSecondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                tieneCodigo ? Icons.check : Icons.qr_code_scanner,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              sabor,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              tieneCodigo ? 'Código: $codigo' : 'Sin código asignado',
                              style: TextStyle(
                                fontSize: 12,
                                color: tieneCodigo ? AppColors.accent : AppColors.textSecondary,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    tieneCodigo ? Icons.edit : Icons.add_a_photo,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(sheetContext);
                                    await _escanearCodigoParaSabor(sabor);
                                    _gestionarCodigosBarras();
                                  },
                                  tooltip: tieneCodigo ? 'Cambiar código' : 'Escanear código',
                                ),
                                if (tieneCodigo)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        _codigosPorSabor.remove(sabor);
                                      });
                                      setState(() {});
                                    },
                                    tooltip: 'Eliminar código',
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Asigna un código de barras único a cada sabor del producto',
                              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _verImagenCompleta() {
    if (_imagenSeleccionada != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text('Imagen del Producto', style: TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
            ),
            body: Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.file(
                  _imagenSeleccionada!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  String _extraerPublicIdCloudinary(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;

      final uploadIndex = path.indexOf('/upload/');
      if (uploadIndex == -1) return '';

      String afterUpload = path.substring(uploadIndex + 8);
      afterUpload = afterUpload.replaceAll(RegExp(r'^v\d+/'), '');
      final publicId = afterUpload.replaceAll(RegExp(r'\.[^.]*$'), '');

      return publicId;
    } catch (e) {
      print('Error extrayendo public_id: $e');
    }
    return '';
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Imagen del Producto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 24),
              ),
              title: const Text('Tomar foto', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.pop(sheetContext);
                _tomarFoto();
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.accent, size: 24),
              ),
              title: const Text('Seleccionar de galería', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.pop(sheetContext);
                _seleccionarDelGalerista();
              },
            ),
            if (_imagenSeleccionada != null) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.visibility, color: AppColors.primary, size: 24),
                ),
                title: const Text('Ver imagen seleccionada', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _verImagenCompleta();
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete, color: AppColors.error, size: 24),
                ),
                title: const Text('Eliminar imagen seleccionada', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _imagenSeleccionada = null;
                  });
                },
              ),
            ],
            if (_imagenActual != null && _imagenActual!.startsWith('http') && _imagenSeleccionada == null) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.visibility, color: AppColors.primary, size: 24),
                ),
                title: const Text('Ver imagen actual', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _verImagenActual();
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete, color: AppColors.error, size: 24),
                ),
                title: const Text('Eliminar imagen actual', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _eliminarImagenActual();
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _verImagenActual() {
    if (_imagenActual != null && _imagenActual!.startsWith('http')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text('Imagen del Producto', style: TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
            ),
            body: Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  _imagenActual!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  void _eliminarImagenActual() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Imagen'),
          ],
        ),
        content: const Text('¿Estás seguro de que deseas eliminar la imagen actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final publicId = _extraerPublicIdCloudinary(_imagenActual!);
              if (publicId.isNotEmpty) {
                await _cloudinaryHelper.eliminarImagen(publicId);
              }

              if (mounted) {
                setState(() {
                  _imagenActual = null;
                  _imagenSeleccionada = null;
                });

                _mostrarSnackBar('Imagen eliminada', isSuccess: true);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      String? imagenUrl = _imagenActual;

      if (_imagenSeleccionada != null) {
        setState(() => _subiendoImagen = true);

        try {
          final nuevaUrl = await _cloudinaryHelper.subirImagenProducto(_imagenSeleccionada!);

          if (nuevaUrl == null) {
            if (mounted) {
              setState(() => _subiendoImagen = false);
              _mostrarSnackBar('No se pudo subir la imagen', isError: true);
            }
            return;
          }

          imagenUrl = nuevaUrl;

          if (_imagenActual != null && _imagenActual!.contains('cloudinary')) {
            try {
              final publicId = _extraerPublicIdCloudinary(_imagenActual!);
              if (publicId.isNotEmpty) {
                await _cloudinaryHelper.eliminarImagen(publicId);
              }
            } catch (e) {
              print('Error al eliminar imagen anterior: $e');
            }
          }

          if (mounted) {
            setState(() => _subiendoImagen = false);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _subiendoImagen = false);
            _mostrarSnackBar('Error: $e', isError: true);
          }
          return;
        }
      }

      final sabores = _saborControllers
          .where((controller) => controller.text.isNotEmpty)
          .map((controller) => controller.text.trim())
          .toList();

      if (sabores.isEmpty) {
        _mostrarSnackBar('Por favor ingresa al menos un sabor', isError: true);
        return;
      }

      final Map<String, String> codigosFinales = {};
      for (var sabor in sabores) {
        if (_codigosPorSabor.containsKey(sabor)) {
          codigosFinales[sabor] = _codigosPorSabor[sabor]!;
        }
      }

      final productoActualizado = ProductoModel(
        id: widget.producto.id,
        categoriaId: _categoriaSeleccionada.id!,
        nombre: _nombreController.text,
        sabores: sabores,
        precio: double.parse(_precioController.text),
        cantidadPorPaca: _cantidadPacaController.text.isEmpty ? null : int.parse(_cantidadPacaController.text),
        imagenPath: imagenUrl,
        codigosPorSabor: codigosFinales.isEmpty ? null : codigosFinales,
      );

      if (mounted) {
        Navigator.pop(context, productoActualizado);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Editar Producto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección de imagen
              GestureDetector(
                onTap: _mostrarOpcionesImagen,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.surface,
                  ),
                  child: _imagenSeleccionada != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      _imagenSeleccionada!,
                      fit: BoxFit.cover,
                    ),
                  )
                      : _imagenActual != null && _imagenActual!.startsWith('http')
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _imagenActual!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo, size: 32, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Toca para agregar imagen',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Categoría
              DropdownButtonFormField<CategoriaModel>(
                value: _categoriaSeleccionada,
                decoration: _buildInputDecoration(
                  label: 'Categoría',
                  icon: Icons.category,
                ),
                dropdownColor: AppColors.surface,
                items: widget.categorias.map((categoria) {
                  return DropdownMenuItem(
                    value: categoria,
                    child: Text(categoria.nombre, style: const TextStyle(color: AppColors.textPrimary)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoriaSeleccionada = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Nombre del Producto
              TextFormField(
                controller: _nombreController,
                decoration: _buildInputDecoration(
                  label: 'Nombre del Producto',
                  icon: Icons.local_drink,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el nombre del producto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Precio
              TextFormField(
                controller: _precioController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration(
                  label: 'Precio Unitario',
                  icon: Icons.attach_money,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el precio';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor ingresa un precio válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cantidad por Paca
              TextFormField(
                controller: _cantidadPacaController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: 'Cantidad por Paca (Opcional)',
                  icon: Icons.inventory,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (int.tryParse(value) == null) {
                      return 'Por favor ingresa una cantidad válida';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sabores
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_cafe, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sabores',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        if (_saborControllers.length < 10)
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                            onPressed: _agregarSabor,
                            tooltip: 'Agregar sabor',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _saborControllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _saborControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Ej: Natural, Limón',
                                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (index == 0 && (value == null || value.isEmpty)) {
                                      return 'Ingresa al menos un sabor';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (_saborControllers.length > 1)
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close, color: AppColors.error, size: 18),
                                  ),
                                  onPressed: () => _eliminarSabor(index),
                                  tooltip: 'Eliminar sabor',
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botón Códigos de Barras
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _gestionarCodigosBarras,
                  icon: const Icon(Icons.qr_code, size: 20),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Gestionar Códigos de Barras'),
                      if (_codigosPorSabor.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_codigosPorSabor.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _subiendoImagen ? null : _guardarProducto,
                  icon: _subiendoImagen
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _subiendoImagen ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}