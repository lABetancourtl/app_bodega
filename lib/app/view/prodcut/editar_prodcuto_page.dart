import 'dart:io';

import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  late TextEditingController _nombreController;
  late TextEditingController _precioController;
  late TextEditingController _cantidadPacaController;

  late CategoriaModel _categoriaSeleccionada;
  late List<TextEditingController> _saborControllers;
  File? _imagenSeleccionada;

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

    // Si la imagen existe y es válida, establecerla
    if (widget.producto.imagenPath != null &&
          widget.producto.imagenPath!.isNotEmpty) {
      final file = File(widget.producto.imagenPath!);
      if (file.existsSync()) {
        _imagenSeleccionada = file;
      }
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

  void _verImagenCompleta() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Imagen del Producto'),
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
                leading: const Icon(Icons.visibility,),
                title: const Text('Ver imagen',),
                onTap: () {
                  Navigator.pop(context);
                  _verImagenCompleta();
                },
              ),
            if (_imagenSeleccionada != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar imagen',
                    style: TextStyle(color: Colors.red)),
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

  void _guardarProducto() {
    if (_formKey.currentState!.validate()) {
      final sabores = _saborControllers
          .where((controller) => controller.text.isNotEmpty)
          .map((controller) => controller.text)
          .toList();

      if (sabores.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa al menos un sabor')),
        );
        return;
      }

      final productoActualizado = ProductoModel(
        id: widget.producto.id,
        categoriaId: _categoriaSeleccionada.id!,
        nombre: _nombreController.text,
        sabores: sabores,
        precio: double.parse(_precioController.text),
        cantidadPorPaca: _cantidadPacaController.text.isEmpty
            ? null
            : int.parse(_cantidadPacaController.text),
        imagenPath: _imagenSeleccionada?.path,
      );

      Navigator.pop(context, productoActualizado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Producto'),
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
                        'Toca para cambiar imagen',
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
                    _categoriaSeleccionada = value!;
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
                  if (_saborControllers.length < 5)
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
              const SizedBox(height: 32),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardarProducto,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(fontSize: 16, color: Colors.white),
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