import 'dart:io';

import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app_bodega/app/view/barcode/barcode_scaner_page.dart';

import '../../service/cloudinary_helper.dart';

class CrearProductoPage extends StatefulWidget {
  final List<CategoriaModel> categorias;

  const CrearProductoPage({super.key, required this.categorias});

  @override
  State<CrearProductoPage> createState() => _CrearProductoPageState();
}

class _CrearProductoPageState extends State<CrearProductoPage> {
  final CloudinaryHelper _cloudinaryHelper = CloudinaryHelper();
  File? _imagenSeleccionada;
  bool _subiendoImagen = false;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _cantidadPacaController = TextEditingController();

  CategoriaModel? _categoriaSeleccionada;
  List<TextEditingController> _saborControllers = [TextEditingController()];

  // ← NUEVO: Mapa para guardar códigos de barras por sabor
  Map<String, String> _codigosPorSabor = {};

  @override
  void initState() {
    super.initState();
    if (widget.categorias.isNotEmpty) {
      _categoriaSeleccionada = widget.categorias[0];
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al tomar la foto')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al seleccionar la imagen')),
        );
      }
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _tomarFoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Seleccionar de galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarDelGalerista();
              },
            ),
            if (_imagenSeleccionada != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar imagen', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imagenSeleccionada = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // ← NUEVO: Escanear código para un sabor específico
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código "$resultado" asignado a sabor "$sabor"')),
        );
      }
    }
  }

  // ← NUEVO: Mostrar diálogo para gestionar códigos de barras
  void _gestionarCodigosBarras() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Códigos de Barras por Sabor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    if (_saborControllers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Primero agrega sabores al producto',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    ..._saborControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      final sabor = controller.text.trim();

                      if (sabor.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final tieneCodigo = _codigosPorSabor.containsKey(sabor);
                      final codigo = _codigosPorSabor[sabor];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tieneCodigo ? Colors.green : Colors.grey,
                            child: Icon(
                              tieneCodigo ? Icons.check : Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            sabor,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            tieneCodigo
                                ? 'Código: $codigo'
                                : 'Sin código asignado',
                            style: TextStyle(
                              fontSize: 12,
                              color: tieneCodigo ? Colors.green : Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  tieneCodigo ? Icons.edit : Icons.add_a_photo,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _escanearCodigoParaSabor(sabor);
                                  _gestionarCodigosBarras();
                                },
                                tooltip: tieneCodigo ? 'Cambiar código' : 'Escanear código',
                              ),
                              if (tieneCodigo)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
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

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Asigna un código de barras único a cada sabor del producto',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      String? imagenUrl;

      if (_imagenSeleccionada != null) {
        setState(() => _subiendoImagen = true);

        try {
          imagenUrl = await _cloudinaryHelper.subirImagenProducto(_imagenSeleccionada!);
        } catch (e) {
          if (mounted) {
            setState(() => _subiendoImagen = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al subir imagen: $e')),
            );
          }
          return;
        }

        if (imagenUrl == null) {
          if (mounted) {
            setState(() => _subiendoImagen = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo obtener URL de la imagen')),
            );
          }
          return;
        }

        if (mounted) {
          setState(() => _subiendoImagen = false);
        }
      }

      final sabores = _saborControllers
          .map((controller) => controller.text.trim())
          .where((sabor) => sabor.isNotEmpty)
          .toList();

      // Limpiar códigos de sabores que ya no existen
      final Map<String, String> codigosFinales = {};
      for (var sabor in sabores) {
        if (_codigosPorSabor.containsKey(sabor)) {
          codigosFinales[sabor] = _codigosPorSabor[sabor]!;
        }
      }

      final nuevoProducto = ProductoModel(
        nombre: _nombreController.text,
        categoriaId: _categoriaSeleccionada!.id!,
        sabores: sabores,
        precio: double.parse(_precioController.text),
        cantidadPorPaca: _cantidadPacaController.text.isEmpty
            ? null
            : int.parse(_cantidadPacaController.text),
        imagenPath: imagenUrl,
        codigosPorSabor: codigosFinales.isEmpty ? null : codigosFinales, // ← NUEVO
      );

      if (mounted) {
        Navigator.pop(context, nuevoProducto);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Producto'),
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
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[100],
                  ),
                  child: _imagenSeleccionada != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _imagenSeleccionada!,
                      fit: BoxFit.cover,
                    ),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: Colors.blue[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Toca para agregar imagen',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Categoría
              DropdownButtonFormField<CategoriaModel>(
                value: _categoriaSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: widget.categorias.map((categoria) {
                  return DropdownMenuItem(
                    value: categoria,
                    child: Text(categoria.nombre),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoriaSeleccionada = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Nombre del Producto
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Producto',
                  hintText: 'Ej: Coca Cola',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.local_drink),
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
                decoration: InputDecoration(
                  labelText: 'Precio Unitario',
                  hintText: 'Ej: 1500',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
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
                decoration: InputDecoration(
                  labelText: 'Cantidad por Paca (Opcional)',
                  hintText: 'Ej: 24',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.inventory),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sabores',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_saborControllers.length < 10)
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: _agregarSabor,
                      tooltip: 'Agregar sabor',
                    ),
                ],
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _saborControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _saborControllers[index],
                            decoration: InputDecoration(
                              labelText: _saborControllers.length == 1
                                  ? 'Sabor Único'
                                  : 'Sabor ${index + 1}',
                              hintText: 'Ej: Fresa',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_saborControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarSabor(index),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // ← NUEVO: Botón para gestionar códigos de barras
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _gestionarCodigosBarras,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Códigos de Barras por Sabor'),
                      if (_codigosPorSabor.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_codigosPorSabor.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _subiendoImagen ? null : _guardarProducto,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    _subiendoImagen ? 'Subiendo imagen...' : 'Guardar Producto',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}