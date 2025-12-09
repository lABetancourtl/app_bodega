import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:app_bodega/app/view/client/selector_ubicacion_mapa.dart';
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
  void initState() {
    super.initState();
    // Asegurar que empieza sin ubicación
    _latitud = null;
    _longitud = null;
  }

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
    setState(() {
      _cargandoUbicacion = true;
      _latitud = null;
      _longitud = null;
    });

    try {
      final locationService = LocationService();

      final position = await locationService.obtenerUbicacionPrecisa(
        onProgress: (accuracy) {
          print('Precisión actual: ${accuracy.toStringAsFixed(1)}m');
        },
        precisionObjetivo: 8.0, // metros
        timeout: const Duration(seconds: 15),
      );

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
              backgroundColor: Colors.black54,
              duration: Duration(milliseconds: 1300),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener la ubicación'),
              backgroundColor: Colors.black54,
              duration: Duration(milliseconds: 1300),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.black54,
            duration: Duration(milliseconds: 1300),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoUbicacion = false);
      }
    }
  }

  Future<void> _seleccionarEnMapa() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectorUbicacionMapa(
          latitudInicial: _latitud,
          longitudInicial: _longitud,
        ),
      ),
    );

    if (resultado != null && mounted) {
      setState(() {
        _latitud = resultado['latitud'];
        _longitud = resultado['longitud'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación seleccionada desde el mapa'),
          backgroundColor: Colors.black54,
          duration: Duration(milliseconds: 1300),
        ),
      );
    }
  }

  void _eliminarUbicacion() {
    setState(() {
      _latitud = null;
      _longitud = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ubicación eliminada'),
        backgroundColor: Colors.black54,
        duration: Duration(milliseconds: 1300),
      ),
    );
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

              // Teléfono
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
                  labelText: 'Observaciones ',
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
                  border: Border.all(
                      color: Colors.black54
                  ),
                  borderRadius: BorderRadius.circular(8),
                  // color: Colors.blue[50],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicación del Negocio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mostrar ubicación capturada si existe
                    if (_latitud != null && _longitud != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ubicación guardada',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    'Lat: ${_latitud?.toStringAsFixed(6)}, Lon: ${_longitud?.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: Colors.red[300]),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Eliminar ubicación',
                              onPressed: _eliminarUbicacion,
                            ),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        // Botón: Capturar ubicación actual
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _cargandoUbicacion ? null : _capturarUbicacion,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue[700],
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _cargandoUbicacion ? Colors.grey : Colors.blue[700]!,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _cargandoUbicacion
                                    ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.blue[700],
                                  ),
                                )
                                    : Icon(
                                  Icons.my_location,
                                  size: 28,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _cargandoUbicacion
                                      ? 'Obteniendo...'
                                      : (_latitud != null ? 'Recapturar GPS' : 'Capturar GPS'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _cargandoUbicacion ? Colors.grey : Colors.blue[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Botón: Seleccionar en mapa
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _seleccionarEnMapa,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.map,
                                  size: 28,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _latitud != null ? 'Editar Mapa' : 'Abrir Mapa',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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