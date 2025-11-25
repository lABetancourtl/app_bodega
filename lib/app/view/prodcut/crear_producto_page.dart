import 'package:app_bodega/app/model/categoria_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:flutter/material.dart';

class CrearProductoPage extends StatefulWidget {
  final List<CategoriaModel> categorias;

  const CrearProductoPage({super.key, required this.categorias});

  @override
  State<CrearProductoPage> createState() => _CrearProductoPageState();
}

class _CrearProductoPageState extends State<CrearProductoPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _cantidadPacaController = TextEditingController();

  CategoriaModel? _categoriaSeleccionada;
  List<TextEditingController> _saborControllers = [TextEditingController()];

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
    setState(() {
      _saborControllers[index].dispose();
      _saborControllers.removeAt(index);
    });
  }

  void _guardarProducto() {
    if (_formKey.currentState!.validate()) {
      // Validar que haya al menos un sabor con contenido
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

      final nuevoProducto = ProductoModel(
        categoriaId: _categoriaSeleccionada!.id!,
        nombre: _nombreController.text,
        sabores: sabores,
        precio: double.parse(_precioController.text),
        cantidadPorPaca: _cantidadPacaController.text.isEmpty
            ? null
            : int.parse(_cantidadPacaController.text),
      );

      Navigator.pop(context, nuevoProducto);
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
                    'Guardar Producto',
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