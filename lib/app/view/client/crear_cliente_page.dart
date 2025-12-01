import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CrearClientePage extends StatefulWidget {
  const CrearClientePage({super.key});

  @override
  State<CrearClientePage> createState() => _CrearClientePageState();
}

class _CrearClientePageState extends State<CrearClientePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _nombreNegocioController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  Ruta? _rutaSeleccionada = Ruta.ruta1;
  double? _latitud;
  double? _longitud;
  bool _cargandoUbicacion = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _nombreNegocioController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _capturarUbicacion() async {
    setState(() => _cargandoUbicacion = true);

    try {
      final locationService = LocationService();
      final position = await locationService.obtenerUbicacionActual();

      if (position != null) {
        setState(() {
          _latitud = position.latitude;
          _longitud = position.longitude;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ubicación capturada: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener la ubicación'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _cargandoUbicacion = false);
    }
  }

  void _guardarCliente() {
    if (_formKey.currentState!.validate()) {
      final nuevoCliente = ClienteModel(
        nombre: _nombreController.text,
        nombreNegocio: _nombreNegocioController.text,
        direccion: _direccionController.text,
        telefono: _telefonoController.text,
        ruta: _rutaSeleccionada!,
        observaciones: _observacionesController.text.isEmpty ? null : _observacionesController.text,
        latitud: _latitud,
        longitud: _longitud,
      );

      Navigator.pop(context, nuevoCliente);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Cliente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Nombre Cliente
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Cliente',
                  hintText: 'Ej: Juan Pérez',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el nombre del cliente';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nombre Negocio
              TextFormField(
                controller: _nombreNegocioController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Negocio',
                  hintText: 'Ej: Tienda Juan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el nombre del negocio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dirección
              TextFormField(
                controller: _direccionController,
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Ej: Calle Principal 123',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa la dirección';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Teléfono (NUEVO)
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Teléfono (Opcional)',
                  hintText: 'Ej: 3001234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              // Ruta (Dropdown)
              DropdownButtonFormField<Ruta>(
                value: _rutaSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Ruta',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.directions),
                ),
                items: Ruta.values.map((ruta) {
                  return DropdownMenuItem(
                    value: ruta,
                    child: Text(ruta.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _rutaSeleccionada = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Observaciones
              TextFormField(
                controller: _observacionesController,
                decoration: InputDecoration(
                  labelText: 'Observaciones (Opcional)',
                  hintText: 'Ej: No compra los martes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue[50],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicación del Negocio (Opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_latitud != null && _longitud != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ubicación capturada',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Lat: ${_latitud?.toStringAsFixed(6)}, Lon: ${_longitud?.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: _cargandoUbicacion ? null : _capturarUbicacion,
                      icon: _cargandoUbicacion
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _cargandoUbicacion ? 'Obteniendo ubicación...' : 'Capturar Ubicación Actual',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botón Guardar
              ElevatedButton(
                onPressed: _guardarCliente,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Guardar Cliente',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
