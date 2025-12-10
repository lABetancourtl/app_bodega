import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:app_bodega/app/service/location_service.dart';
import 'package:app_bodega/app/view/client/selector_ubicacion_mapa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_bodega/app/theme/app_colors.dart';


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
        precisionObjetivo: 8.0,
        timeout: const Duration(seconds: 5),
      );

      if (position != null) {
        setState(() {
          _latitud = position.latitude;
          _longitud = position.longitude;
        });

        if (mounted) {
          _mostrarSnackBar(
            'Ubicación capturada: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            isSuccess: true,
          );
        }
      } else {
        if (mounted) {
          _mostrarSnackBar('No se pudo obtener la ubicación', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error: $e', isError: true);
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

      _mostrarSnackBar('Ubicación seleccionada desde el mapa', isSuccess: true);
    }
  }

  void _eliminarUbicacion() {
    setState(() {
      _latitud = null;
      _longitud = null;
    });

    _mostrarSnackBar('Ubicación eliminada', isSuccess: true);
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
          'Agregar Cliente',
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
              // Header de sección
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información del Cliente',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Completa los datos del nuevo cliente',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nombre Cliente
              TextFormField(
                controller: _nombreController,
                decoration: _buildInputDecoration(
                  label: 'Nombre del Cliente',
                  hint: 'Ej: Juan Pérez',
                  icon: Icons.person,
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
                decoration: _buildInputDecoration(
                  label: 'Nombre del Negocio',
                  hint: 'Ej: Tienda Juan',
                  icon: Icons.store,
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
                decoration: _buildInputDecoration(
                  label: 'Dirección',
                  hint: 'Ej: Calle Principal 123',
                  icon: Icons.location_on,
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
                decoration: _buildInputDecoration(
                  label: 'Teléfono (Opcional)',
                  hint: 'Ej: 3001234567',
                  icon: Icons.phone,
                ),
              ),
              const SizedBox(height: 16),

              // Ruta (Dropdown)
              DropdownButtonFormField<Ruta>(
                value: _rutaSeleccionada,
                decoration: _buildInputDecoration(
                  label: 'Ruta',
                  icon: Icons.route,
                ),
                dropdownColor: AppColors.surface,
                items: Ruta.values.map((ruta) {
                  return DropdownMenuItem(
                    value: ruta,
                    child: Text(
                      ruta.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
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
                decoration: _buildInputDecoration(
                  label: 'Observaciones (Opcional)',
                  icon: Icons.note,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Sección de ubicación
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Ubicación del Negocio',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mostrar ubicación capturada si existe
                    if (_latitud != null && _longitud != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          border: Border.all(color: AppColors.accent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ubicación guardada',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                  Text(
                                    'Lat: ${_latitud?.toStringAsFixed(6)}, Lon: ${_longitud?.toStringAsFixed(6)}',
                                    style: TextStyle(fontSize: 11, color: AppColors.accent.withOpacity(0.8)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.close, size: 16, color: AppColors.error),
                              ),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _cargandoUbicacion ? AppColors.border : AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _cargandoUbicacion
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                )
                                    : const Icon(Icons.my_location, size: 24, color: AppColors.primary),
                                const SizedBox(height: 6),
                                Text(
                                  _cargandoUbicacion
                                      ? 'Obteniendo...'
                                      : (_latitud != null ? 'Recapturar GPS' : 'Capturar GPS'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _cargandoUbicacion ? AppColors.textSecondary : AppColors.primary,
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map, size: 24, color: Colors.white),
                                const SizedBox(height: 6),
                                Text(
                                  _latitud != null ? 'Editar Mapa' : 'Abrir Mapa',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardarCliente,
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Guardar Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
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