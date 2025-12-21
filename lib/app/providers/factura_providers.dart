import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/database_helper.dart';
import '../model/factura_model.dart';

// ============= STATE PARA FECHA =============
class FechaState {
  final DateTime fechaSeleccionada;

  FechaState({required this.fechaSeleccionada});

  FechaState copyWith({DateTime? fechaSeleccionada}) {
    return FechaState(
      fechaSeleccionada: fechaSeleccionada ?? this.fechaSeleccionada,
    );
  }
}

class FechaNotifier extends StateNotifier<FechaState> {
  FechaNotifier() : super(FechaState(fechaSeleccionada: DateTime.now()));

  void setFecha(DateTime fecha) {
    state = state.copyWith(fechaSeleccionada: fecha);
  }
}

final fechaProvider = StateNotifierProvider<FechaNotifier, FechaState>((ref) {
  return FechaNotifier();
});

// ============= STATE PARA FACTURAS =============
class FacturasNotifier extends StateNotifier<AsyncValue<List<FacturaModel>>> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  FacturasNotifier() : super(const AsyncValue.loading()) {
    cargarFacturas();
  }

  Future<void> cargarFacturas() async {
    state = const AsyncValue.loading();
    try {
      final facturas = await _dbHelper.obtenerFacturas();
      state = AsyncValue.data(facturas);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // ✅ AGREGAR UNA NUEVA FACTURA SIN RECARGAR TODO
  void agregarFactura(FacturaModel factura) {
    state.whenData((facturas) {
      final nuevasFacturas = [factura, ...facturas]; // Agregar al inicio
      state = AsyncValue.data(nuevasFacturas);
    });
  }

  // ✅ ACTUALIZAR UNA FACTURA EXISTENTE
  void actualizarFactura(FacturaModel facturaActualizada) {
    state.whenData((facturas) {
      final index = facturas.indexWhere((f) => f.id == facturaActualizada.id);
      if (index != -1) {
        final nuevasFacturas = [...facturas];
        nuevasFacturas[index] = facturaActualizada;
        nuevasFacturas.sort((a, b) => b.fecha.compareTo(a.fecha)); // Reordenar
        state = AsyncValue.data(nuevasFacturas);
      }
    });
  }

  // ✅ ELIMINAR UNA FACTURA
  void eliminarFactura(String facturaId) {
    state.whenData((facturas) {
      final nuevasFacturas = facturas.where((f) => f.id != facturaId).toList();
      state = AsyncValue.data(nuevasFacturas);
    });
  }
}

final facturasStateProvider = StateNotifierProvider<FacturasNotifier, AsyncValue<List<FacturaModel>>>((ref) {
  return FacturasNotifier();
});

// ============= PROVIDER DE FACTURAS FILTRADAS =============
final facturasFiltradasProvider = Provider<List<FacturaModel>>((ref) {
  final facturasAsync = ref.watch(facturasStateProvider);
  final fechaState = ref.watch(fechaProvider);

  return facturasAsync.whenData((facturas) {
    final fecha = fechaState.fechaSeleccionada;
    return facturas.where((factura) {
      return factura.fecha.year == fecha.year &&
          factura.fecha.month == fecha.month &&
          factura.fecha.day == fecha.day;
    }).toList();
  }).maybeWhen(
    data: (data) => data,
    orElse: () => [],
  );
});

// Provider para controlar si está buscando
final isSearchingFacturasProvider = StateProvider<bool>((ref) => false);

// Provider para el término de búsqueda
final searchQueryFacturasProvider = StateProvider<String>((ref) => '');

// Provider para facturas filtradas por fecha Y búsqueda
final facturasFiltradasConBusquedaProvider = Provider<List<FacturaModel>>((ref) {
  final facturas = ref.watch(facturasStateProvider).value ?? [];
  final fechaState = ref.watch(fechaProvider);
  final searchQuery = ref.watch(searchQueryFacturasProvider).toLowerCase();

  return facturas.where((factura) {
    // Filtrar por fecha
    final mismoDia = factura.fecha.year == fechaState.fechaSeleccionada.year &&
        factura.fecha.month == fechaState.fechaSeleccionada.month &&
        factura.fecha.day == fechaState.fechaSeleccionada.day;

    if (!mismoDia) return false;

    // Si no hay búsqueda, mostrar todos
    if (searchQuery.isEmpty) return true;

    // Filtrar por búsqueda
    final nombreCliente = factura.nombreCliente.toLowerCase();
    final negocio = (factura.negocioCliente ?? '').toLowerCase();
    final direccion = factura.direccionCliente.toLowerCase();

    return nombreCliente.contains(searchQuery) ||
        negocio.contains(searchQuery) ||
        direccion.contains(searchQuery);
  }).toList();
});