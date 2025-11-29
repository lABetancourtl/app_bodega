import 'package:app_bodega/app/datasources/database_helper.dart';
import 'package:app_bodega/app/model/factura_model.dart';
import 'package:app_bodega/app/model/prodcuto_model.dart';
import 'package:flutter/material.dart';

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
  Map<String, String> _productosCategorias = {}; // productoId -> categoriaId
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
          resumen[item.productoId] = {
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

    // Filtrar por categoría
    if (_categoriaSeleccionada != null) {
      productosFiltrados = Map.fromEntries(
        productosFiltrados.entries.where((entry) {
          final categoriaDelProducto = _productosCategorias[entry.key];
          return categoriaDelProducto == _categoriaSeleccionada;
        }),
      );
    }

    // Filtrar por búsqueda
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

  @override
  Widget build(BuildContext context) {
    final resumen = _calcularResumenProductos();
    final resumenFiltrado = _filtrarProductos(resumen);
    final productos = resumenFiltrado.entries.toList();

    productos.sort((a, b) =>
        (b.value['cantidadTotal'] as int).compareTo(a.value['cantidadTotal'] as int)
    );

    final totalGeneral = productos.fold(0.0, (sum, p) => sum + (p.value['subtotal'] as double));
    final cantidadTotalProductos = productos.fold(0, (sum, p) => sum + (p.value['cantidadTotal'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resumen de Productos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
      ),
      body: Column(
        children: [
          // Encabezado con fecha y totales
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      _formatearFecha(widget.fecha),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Facturas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${widget.facturas.length}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Productos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$cantidadTotalProductos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '\$${_formatearPrecio(totalGeneral)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
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
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre...',
                prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                suffixIcon: _busquedaController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.blue.shade700),
                  onPressed: () {
                    _busquedaController.clear();
                    setState(() {});
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Fila de categorías
          if (!_cargandoCategorias)
            FutureBuilder(
              future: _dbHelper.obtenerCategorias(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 50);
                }

                final todasCategorias = snapshot.data!;
                final categoriasConProductos = _obtenerCategoriasConProductos(resumen);

                // Filtrar solo las categorías que tienen productos en este resumen
                final categorias = todasCategorias
                    .where((cat) => categoriasConProductos.contains(cat.id))
                    .toList();

                if (categorias.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: const Text('Todas'),
                          selected: _categoriaSeleccionada == null,
                          onSelected: (selected) {
                            setState(() {
                              _categoriaSeleccionada = null;
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _categoriaSeleccionada == null ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      ...categorias.map((categoria) {
                        final isSelected = _categoriaSeleccionada == categoria.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(categoria.nombre),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _categoriaSeleccionada = categoria.id;
                              });
                            },
                            backgroundColor: Colors.grey[200],
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        );
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
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _busquedaController.text.isEmpty && _categoriaSeleccionada == null
                        ? 'No hay productos para esta fecha'
                        : 'No se encontraron productos',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
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

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  elevation: 2,
                  child: ExpansionTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$cantidadTotal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      nombreProducto,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Precio unitario: \$${_formatearPrecio(precioUnitario)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Subtotal: \$${_formatearPrecio(subtotal)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    children: tieneSabores && sabores.isNotEmpty
                        ? [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.list_alt, size: 18, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Distribución por sabor:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                    fontSize: 14,
                                  ),
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
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${entry.value} unidades',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                          fontSize: 13,
                                        ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}