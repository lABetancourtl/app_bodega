import '../../datasources/database_helper.dart';
import '../../model/factura_model.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../service/esc_pos_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ResumenProductosDiaPage extends StatefulWidget {
  final List<FacturaModel> facturas;
  final DateTime fecha;

  const ResumenProductosDiaPage({
    super.key,
    required this.facturas,
    required this.fecha,
  });

  @override
  State<ResumenProductosDiaPage> createState() => _ResumenProductosDiaPageState();
}

class _ResumenProductosDiaPageState extends State<ResumenProductosDiaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TextEditingController _busquedaController;
  String? _categoriaSeleccionada;
  Map<String, String> _productosCategorias = {};
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarCategoriasProductos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategoriasProductos() async {
    try {
      final productos = await _dbHelper.obtenerTodosProductos();
      final Map<String, String> categorias = {};

      for (var producto in productos) {
        if (producto.categoriaId != null) {
          categorias[producto.id!] = producto.categoriaId!;
        }
      }

      if (mounted) {
        setState(() {
          _productosCategorias = categorias;
          _cargandoCategorias = false;
        });
      }
    } catch (e) {
      print('Error al cargar categorías: $e');
      if (mounted) {
        setState(() {
          _cargandoCategorias = false;
        });
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatearPrecio(double precio) {
    final precioInt = precio.toInt();
    return precioInt.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  Map<String, Map<String, dynamic>> _calcularResumenProductos() {
    final Map<String, Map<String, dynamic>> resumen = {};

    for (var factura in widget.facturas) {
      for (var item in factura.items) {
        if (!resumen.containsKey(item.productoId)) {
          resumen[item.productoId!] = {
            'nombreProducto': item.nombreProducto,
            'precioUnitario': item.precioUnitario,
            'cantidadTotal': 0,
            'tieneSabores': item.tieneSabores,
            'sabores': <String, int>{},
            'subtotal': 0.0,
          };
        }

        resumen[item.productoId]!['cantidadTotal'] += item.cantidadTotal;

        if (item.tieneSabores) {
          item.cantidadPorSabor.forEach((sabor, cantidad) {
            if (cantidad > 0) {
              resumen[item.productoId]!['sabores'][sabor] =
                  (resumen[item.productoId]!['sabores'][sabor] ?? 0) + cantidad;
            }
          });
        }

        resumen[item.productoId]!['subtotal'] += item.subtotal;
      }
    }

    return resumen;
  }

  Map<String, Map<String, dynamic>> _filtrarProductos(
      Map<String, Map<String, dynamic>> resumen,
      ) {
    var productosFiltrados = resumen;

    if (_categoriaSeleccionada != null) {
      productosFiltrados = Map.fromEntries(
        productosFiltrados.entries.where((entry) {
          final categoriaDelProducto = _productosCategorias[entry.key];
          return categoriaDelProducto == _categoriaSeleccionada;
        }),
      );
    }

    final busqueda = _busquedaController.text.toLowerCase();
    if (busqueda.isNotEmpty) {
      productosFiltrados = Map.fromEntries(
        productosFiltrados.entries.where((entry) {
          final nombreProducto = (entry.value['nombreProducto'] as String).toLowerCase();
          return nombreProducto.contains(busqueda);
        }),
      );
    }

    return productosFiltrados;
  }

  Set<String> _obtenerCategoriasConProductos(Map<String, Map<String, dynamic>> resumen) {
    final Set<String> categoriasUsadas = {};

    for (var productoId in resumen.keys) {
      final categoriaId = _productosCategorias[productoId];
      if (categoriaId != null) {
        categoriasUsadas.add(categoriaId);
      }
    }

    return categoriasUsadas;
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

  Future<void> _imprimirResumen() async {
    try {
      final resumen = _calcularResumenProductos();

      // Mostrar diálogo de búsqueda
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Buscando impresora...', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );

      List<BluetoothDevice> impresoras = await EscPosService.escanearImpresorasBluetooth();

      if (mounted) {
        Navigator.pop(context);
      }

      if (impresoras.isEmpty) {
        if (mounted) {
          _mostrarSnackBar('No se encontraron impresoras Bluetooth', isError: true);
        }
        return;
      }

      if (mounted) {
        final impresoraSeleccionada = await showDialog<BluetoothDevice>(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Seleccionar Impresora'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: impresoras.length,
                  itemBuilder: (context, index) {
                    final impresora = impresoras[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        impresora.platformName.isNotEmpty ? impresora.platformName : 'Impresora ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(impresora.remoteId.toString(), style: const TextStyle(fontSize: 12)),
                      onTap: () => Navigator.pop(context, impresora),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            );
          },
        );

        if (impresoraSeleccionada == null) return;

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // Conectar a la impresora
        final connectResult = await EscPosService.connectToDevice(impresoraSeleccionada);

        if (connectResult != BluetoothConnectionResult.success) {
          if (mounted) {
            Navigator.pop(context);
            _mostrarSnackBar('Error al conectar: ${connectResult.name}', isError: true);
          }
          return;
        }

        // Generar e imprimir
        final bytes = await EscPosService.generarResumenProductosEscPos(
          widget.fecha,
          resumen,
          widget.facturas.length,
        );

        await EscPosService.sendPrintData(bytes);
        await Future.delayed(const Duration(seconds: 2));
        await EscPosService.disconnectPrinter();

        if (mounted) {
          Navigator.pop(context);
          _mostrarSnackBar('Resumen impreso correctamente', isSuccess: true);
        }
      }
    } catch (e) {
      await EscPosService.disconnectPrinter();
      if (mounted) {
        Navigator.of(context).pop();
        _mostrarSnackBar('Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _calcularResumenProductos();
    final resumenFiltrado = _filtrarProductos(resumen);
    final productos = resumenFiltrado.entries.toList();

    productos.sort((a, b) => (b.value['cantidadTotal'] as int).compareTo(a.value['cantidadTotal'] as int));

    final totalGeneral = productos.fold(0.0, (sum, p) => sum + (p.value['subtotal'] as double));
    final cantidadTotalProductos = productos.fold(0, (sum, p) => sum + (p.value['cantidadTotal'] as int));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Resumen de Productos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppColors.primary),
            onPressed: _imprimirResumen,
            tooltip: 'Imprimir resumen',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con fecha y totales
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
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
                      child: const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatearFecha(widget.fecha),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard('Facturas', '${widget.facturas.length}', Icons.receipt),
                    const SizedBox(width: 12),
                    _buildStatCard('Productos', '$cantidadTotalProductos', Icons.inventory_2),
                    const SizedBox(width: 12),
                    _buildStatCard('Total', '\$${_formatearPrecio(totalGeneral)}', Icons.attach_money, isAccent: true),
                  ],
                ),
              ],
            ),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _busquedaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _busquedaController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _busquedaController.clear();
                    setState(() {});
                  },
                )
                    : null,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),

          // Filtros de categoría
          if (!_cargandoCategorias)
            FutureBuilder(
              future: _dbHelper.obtenerCategorias(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 50);
                }

                final todasCategorias = snapshot.data!;
                final categoriasConProductos = _obtenerCategoriasConProductos(resumen);

                final categorias = todasCategorias.where((cat) => categoriasConProductos.contains(cat.id)).toList();

                if (categorias.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildFilterChip('Todas', _categoriaSeleccionada == null, () {
                        setState(() => _categoriaSeleccionada = null);
                      }),
                      ...categorias.map((categoria) {
                        final isSelected = _categoriaSeleccionada == categoria.id;
                        return _buildFilterChip(categoria.nombre, isSelected, () {
                          setState(() => _categoriaSeleccionada = categoria.id);
                        });
                      }).toList(),
                    ],
                  ),
                );
              },
            ),

          // Lista de productos
          Expanded(
            child: productos.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary.withOpacity(0.3)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _busquedaController.text.isEmpty && _categoriaSeleccionada == null
                        ? 'No hay productos para esta fecha'
                        : 'No se encontraron productos',
                    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: productos.length,
              itemBuilder: (context, index) {
                final producto = productos[index];
                final datos = producto.value;
                final nombreProducto = datos['nombreProducto'] as String;
                final cantidadTotal = datos['cantidadTotal'] as int;
                final precioUnitario = datos['precioUnitario'] as double;
                final subtotal = datos['subtotal'] as double;
                final tieneSabores = datos['tieneSabores'] as bool;
                final sabores = datos['sabores'] as Map<String, int>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$cantidadTotal',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      title: Text(
                        nombreProducto,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Precio: \$${_formatearPrecio(precioUnitario)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Subtotal: \$${_formatearPrecio(subtotal)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      children: tieneSabores && sabores.isNotEmpty
                          ? [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.list_alt, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Distribución por sabor:',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...sabores.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.key, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${entry.value} unidades',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ]
                          : [],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool isAccent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAccent ? AppColors.accentLight : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAccent ? AppColors.accent.withOpacity(0.3) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isAccent ? AppColors.accent : AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAccent ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}