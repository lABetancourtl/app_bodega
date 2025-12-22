import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../datasources/database_helper.dart';
import '../../model/cliente_model.dart';
import '../../model/factura_model.dart';
import '../../model/prodcuto_model.dart';
import '../../providers/factura_providers.dart';
import '../../view/factura/agregar_prodcuto_factura_page.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'factura_page.dart';
import 'seleccionar_cliente_page.dart';
// import 'factura_mobile.dart';

class CrearFacturaMobile extends ConsumerStatefulWidget {
  final List<ItemFacturaModel>? itemsIniciales;

  const CrearFacturaMobile({
    super.key,
    this.itemsIniciales,
  });

  @override
  ConsumerState<CrearFacturaMobile> createState() => _CrearFacturaMobileState();
}

class _CrearFacturaMobileState extends ConsumerState<CrearFacturaMobile> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  DescuentoModel? descuentoGlobal;

  ClienteModel? clienteSeleccionado;
  List<ItemFacturaModel> items = [];
  bool esFacturaLimpia = false;

  @override
  void initState() {
    super.initState();

    if (widget.itemsIniciales != null && widget.itemsIniciales!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          items = List.from(widget.itemsIniciales!);
        });
        _mostrarSnackBar(
          'Pedido cargado: ${items.length} producto${items.length != 1 ? 's' : ''}',
          isSuccess: true,
        );
      });
    }
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
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
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  // Mostrar menú de selección de tipo de factura
  void _mostrarMenuTipoFactura() {
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
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Seleccionar Cliente',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 24),
              ),
              title: const Text('Cliente Registrado', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Seleccionar de la lista de clientes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.pop(sheetContext);
                _seleccionarClienteRegistrado();
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 24),
              ),
              title: const Text('Factura Limpia', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Cliente ocasional sin registro', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.pop(sheetContext);
                _mostrarFormularioClienteLimpio();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Seleccionar cliente registrado
  void _seleccionarClienteRegistrado() async {
    final cliente = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SeleccionarClientePage()),
    );

    if (cliente != null) {
      setState(() {
        clienteSeleccionado = cliente;
        esFacturaLimpia = false;
      });
    }
  }

  // Mostrar formulario para cliente ocasional (factura limpia)
  void _mostrarFormularioClienteLimpio() async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: clienteSeleccionado?.nombre ?? '');
    final negocioController = TextEditingController(text: clienteSeleccionado?.nombreNegocio ?? '');
    final direccionController = TextEditingController(text: clienteSeleccionado?.direccion ?? '');
    final telefonoController = TextEditingController(text: clienteSeleccionado?.telefono ?? '');
    final observacionesController = TextEditingController(text: clienteSeleccionado?.observaciones ?? '');

    final resultado = await showModalBottomSheet<ClienteModel>(
      context: context,
      isScrollControlled: true, // ✅ IMPORTANTE: Permitir scroll
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet( // ✅ USAR DraggableScrollableSheet
          initialChildSize: 0.9, // Tamaño inicial (90% de la pantalla)
          minChildSize: 0.5,     // Tamaño mínimo (50%)
          maxChildSize: 0.95,    // Tamaño máximo (95%)
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView( // ✅ Hacer scroll al contenido
              controller: scrollController,
              child: Form(
                key: formKey,
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
                            child: const Icon(Icons.person_add, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Datos del Cliente',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'Ingresa la información del cliente',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nombreController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Nombre del Cliente',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El nombre del cliente es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: negocioController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Nombre del Negocio',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.store, color: AppColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El nombre del negocio es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: direccionController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Dirección',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La dirección es requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Teléfono',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El teléfono es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: observacionesController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Observaciones (opcional)',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.note, color: AppColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  final clienteTemporal = ClienteModel(
                                    id: null,
                                    nombre: nombreController.text.trim(),
                                    nombreNegocio: negocioController.text.trim(),
                                    direccion: direccionController.text.trim(),
                                    telefono: telefonoController.text.trim(),
                                    ruta: Ruta.ruta1,
                                    observaciones: observacionesController.text.trim().isEmpty
                                        ? null
                                        : observacionesController.text.trim(),
                                  );
                                  Navigator.pop(context, clienteTemporal);
                                }
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Guardar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        clienteSeleccionado = resultado;
        esFacturaLimpia = true;
      });
      _mostrarSnackBar('Datos del cliente guardados', isSuccess: true);
    }
  }

  void _agregarProducto() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AgregarProductoFacturaPage(),
      ),
    );

    if (resultado != null) {
      setState(() {
        // ← NUEVO: Manejar el resultado que ahora es un Map
        if (resultado is Map<String, dynamic>) {
          final itemsRecibidos = resultado['items'] as List<ItemFacturaModel>;
          final descuentoGlobalRecibido = resultado['descuentoGlobal'] as DescuentoModel?;

          // Guardar el descuento global
          descuentoGlobal = descuentoGlobalRecibido;

          // Procesar items
          for (var nuevoItem in itemsRecibidos) {
            final indexExistente = items.indexWhere(
                  (item) => item.productoId == nuevoItem.productoId,
            );

            if (indexExistente != -1) {
              items[indexExistente] = nuevoItem;
            } else {
              items.add(nuevoItem);
            }
          }

          _mostrarSnackBar(
            '${itemsRecibidos.length} ${itemsRecibidos.length == 1 ? "producto procesado" : "productos procesados"}',
            isSuccess: true,
          );
        }
        // ← MANTENER compatibilidad con formato antiguo (por si acaso)
        else if (resultado is List<ItemFacturaModel>) {
          for (var nuevoItem in resultado) {
            final indexExistente = items.indexWhere(
                  (item) => item.productoId == nuevoItem.productoId,
            );

            if (indexExistente != -1) {
              items[indexExistente] = nuevoItem;
            } else {
              items.add(nuevoItem);
            }
          }

          _mostrarSnackBar(
            '${resultado.length} ${resultado.length == 1 ? "producto procesado" : "productos procesados"}',
            isSuccess: true,
          );
        } else if (resultado is ItemFacturaModel) {
          final indexExistente = items.indexWhere(
                (item) => item.productoId == resultado.productoId,
          );

          if (indexExistente != -1) {
            items[indexExistente] = resultado;
          } else {
            items.add(resultado);
          }

          _mostrarSnackBar('Producto agregado', isSuccess: true);
        }
      });
    }
  }

  void _eliminarProducto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            const Text('Eliminar Producto'),
          ],
        ),
        content: Text('¿Eliminar "${items[index].nombreProducto}" de la factura?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                items.removeAt(index);
              });
              Navigator.pop(context);
              _mostrarSnackBar('Producto eliminado', isSuccess: true);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _guardarFactura() async {
    if (clienteSeleccionado == null) {
      _mostrarSnackBar('Por favor completa los datos del cliente', isError: true);
      return;
    }

    if (items.isEmpty) {
      _mostrarSnackBar('Por favor agrega al menos un producto', isError: true);
      return;
    }

    // ← CREAR LA FACTURA CON EL DESCUENTO GLOBAL
    final factura = FacturaModel(
      clienteId: esFacturaLimpia ? '' : (clienteSeleccionado!.id ?? ''),
      nombreCliente: clienteSeleccionado!.nombre,
      direccionCliente: clienteSeleccionado!.direccion,
      telefonoCliente: clienteSeleccionado!.telefono,
      negocioCliente: clienteSeleccionado!.nombreNegocio,
      observacionesCliente: clienteSeleccionado!.observaciones,
      fecha: DateTime.now(),
      items: items,
      estado: 'preventa',
      descuentoGlobal: descuentoGlobal, // ← AGREGAR ESTA LÍNEA
    );

    try {
      // Guardar en Supabase y obtener el ID
      final facturaId = await _dbHelper.insertarFactura(factura);

      if (mounted) {
        // Crear factura con el ID usando copyWith
        final facturaConId = factura.copyWith(id: facturaId);

        // ✅ AGREGAR SOLO ESTA FACTURA sin recargar todo
        ref.read(facturasStateProvider.notifier).agregarFactura(facturaConId);

        _mostrarSnackBar('Factura guardada para ${clienteSeleccionado!.nombre}', isSuccess: true);

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _mostrarSnackBar('Error al guardar: $e', isError: true);
    }
  }

  void _editarProducto(int index) async {
    final itemActual = items[index];
    final producto = await _dbHelper.obtenerProductoPorId(itemActual.productoId!);

    if (producto == null) {
      if (mounted) {
        _mostrarSnackBar('No se encontró el producto', isError: true);
      }
      return;
    }

    if (!mounted) return;

    final itemEditado = await _mostrarDialogoEdicion(producto, itemActual);

    if (itemEditado != null) {
      setState(() {
        items[index] = itemEditado;
      });
      _mostrarSnackBar('Producto actualizado', isSuccess: true);
    }
  }

  Future<ItemFacturaModel?> _mostrarDialogoEdicion(
      ProductoModel producto,
      ItemFacturaModel itemActual,
      ) async {
    final TextEditingController cantidadTotalController =
    TextEditingController(text: itemActual.cantidadTotal.toString());
    final Map<String, TextEditingController> controllersPorSabor = {};
    final Map<String, int> cantidadPorSabor = Map.from(itemActual.cantidadPorSabor);

    for (var sabor in producto.sabores) {
      final cantidad = cantidadPorSabor[sabor] ?? 0;
      controllersPorSabor[sabor] = TextEditingController(text: cantidad.toString());
    }

    int calcularTotal() {
      return cantidadPorSabor.values.fold(0, (sum, qty) => sum + qty);
    }

    return await showModalBottomSheet<ItemFacturaModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                          child: const Icon(Icons.edit, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                producto.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '\$${_formatearPrecio(producto.precio)} c/u',
                                style: const TextStyle(fontSize: 14, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (producto.sabores.length == 1) ...[
                          TextField(
                            controller: cantidadTotalController,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Cantidad',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              prefixIcon: const Icon(Icons.inventory, color: AppColors.primary),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (producto.sabores.length > 1) ...[
                          const Text(
                            'Distribuir por sabor:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 16),
                          ...producto.sabores.map((sabor) {
                            final controller = controllersPorSabor[sabor]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sabor,
                                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                      ),
                                      onTap: () {
                                        if (controller.text == '0') {
                                          controller.clear();
                                        }
                                      },
                                      onChanged: (value) {
                                        final cantidad = int.tryParse(value) ?? 0;
                                        cantidadPorSabor[sabor] = cantidad;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.sabores.length == 1
                                        ? '${int.tryParse(cantidadTotalController.text) ?? 0} unidades'
                                        : '${calcularTotal()} unidades',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const Text(
                                    'TOTAL:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Text(
                                producto.sabores.length == 1
                                    ? '\$${_formatearPrecio((int.tryParse(cantidadTotalController.text) ?? 0) * producto.precio)}'
                                    : '\$${_formatearPrecio(calcularTotal() * producto.precio)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              int cantidadTotal;
                              if (producto.sabores.length == 1) {
                                if (cantidadTotalController.text.isEmpty) {
                                  _mostrarSnackBar('Por favor ingresa la cantidad', isError: true);
                                  return;
                                }
                                cantidadTotal = int.parse(cantidadTotalController.text);
                                if (cantidadTotal <= 0) {
                                  _mostrarSnackBar('La cantidad debe ser mayor a 0', isError: true);
                                  return;
                                }
                              } else {
                                cantidadTotal = calcularTotal();
                                if (cantidadTotal <= 0) {
                                  _mostrarSnackBar('Debes agregar al menos una unidad', isError: true);
                                  return;
                                }
                              }
                              final itemActualizado = ItemFacturaModel(
                                productoId: producto.id!,
                                nombreProducto: producto.nombre,
                                precioUnitario: producto.precio,
                                cantidadTotal: cantidadTotal,
                                cantidadPorSabor: producto.sabores.length > 1
                                    ? cantidadPorSabor
                                    : {producto.sabores[0]: cantidadTotal},
                                tieneSabores: producto.sabores.length > 1,
                              );
                              Navigator.pop(context, itemActualizado);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = items.fold(0, (sum, item) => sum + item.subtotal);

    if (descuentoGlobal != null && descuentoGlobal!.tieneDescuento) {
      total = descuentoGlobal!.aplicarDescuento(total);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          esFacturaLimpia ? 'Factura Limpia' : 'Nueva Factura',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _guardarFactura,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Seleccionar Cliente
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _mostrarMenuTipoFactura,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                    color: clienteSeleccionado == null ? AppColors.primary : AppColors.accent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: clienteSeleccionado == null
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        clienteSeleccionado == null
                            ? Icons.person_add
                            : (esFacturaLimpia ? Icons.person_outline : Icons.check_circle),
                        color: clienteSeleccionado == null ? AppColors.primary : AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clienteSeleccionado == null
                                ? 'Seleccionar Cliente'
                                : clienteSeleccionado!.nombreNegocio ?? clienteSeleccionado!.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clienteSeleccionado == null
                                ? 'Toca para seleccionar'
                                : '${clienteSeleccionado!.nombre}${esFacturaLimpia ? ' (Ocasional)' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      clienteSeleccionado == null ? Icons.chevron_right : Icons.edit,
                      color: clienteSeleccionado == null ? AppColors.textSecondary : AppColors.accent,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Lista de productos
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Botón agregar producto
                GestureDetector(
                  onTap: _agregarProducto,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add, color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Agregar productos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Estado vacío
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay productos agregados',
                          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Presiona "Agregar productos" para empezar',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                // Lista de productos
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _editarProducto(index),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.cantidadTotal}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nombreProducto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.tieneSabores)
                                    Text(
                                      item.cantidadPorSabor.entries.map((e) => '${e.key} (${e.value})').join(', '),
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '\$${_formatearPrecio(item.subtotal)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              ),
                              onPressed: () => _eliminarProducto(index),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          _buildResumenDescuentos(),

          // Total
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? "producto" : "productos"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Text(
                      'Total:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '\$${_formatearPrecio(total)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDescuentos() {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    double subtotalSinDescuentos = items.fold(0, (sum, item) => sum + item.subtotalSinDescuento);
    double subtotalConDescuentosItems = items.fold(0, (sum, item) => sum + item.subtotal);

    // Calcular descuento de items
    double descuentoItems = subtotalSinDescuentos - subtotalConDescuentosItems;

    // Calcular descuento global
    double montoDescuentoGlobal = 0;
    if (descuentoGlobal != null && descuentoGlobal!.tieneDescuento) {
      montoDescuentoGlobal = descuentoGlobal!.calcularDescuento(subtotalConDescuentosItems);
    }

    double totalDescuentos = descuentoItems + montoDescuentoGlobal;

    // Solo mostrar si hay descuentos
    if (totalDescuentos <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Descuentos aplicados:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '\$${_formatearPrecio(totalDescuentos)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (descuentoItems > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 26),
                const Text(
                  '• Descuentos por producto',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '\$${_formatearPrecio(descuentoItems)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          if (descuentoGlobal != null && descuentoGlobal!.tieneDescuento) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 26),
                Text(
                  '• Descuento global (${descuentoGlobal!.toString()})',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '\$${_formatearPrecio(montoDescuentoGlobal)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}