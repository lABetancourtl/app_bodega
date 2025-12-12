import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  // Cache de última ubicación válida
  Position? _ultimaUbicacionCache;
  DateTime? _tiempoUltimaUbicacion;
  static const Duration _duracionCache = Duration(seconds: 10);

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// Obtener ubicación RÁPIDA y CONSISTENTE (uso general)
  Future<Position?> obtenerUbicacionActual() async {
    try {
      // Si tenemos cache reciente, usarlo primero
      if (_ultimaUbicacionCache != null && _tiempoUltimaUbicacion != null) {
        final diferencia = DateTime.now().difference(_tiempoUltimaUbicacion!);
        if (diferencia < _duracionCache) {
          print('[LocationService] Usando ubicación en cache (${diferencia.inSeconds}s)');
          return _ultimaUbicacionCache;
        }
      }

      // Verificar servicio
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[LocationService] Servicio de ubicación deshabilitado');
        return _ultimaUbicacionCache; // Retornar cache si existe
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[LocationService] Permisos de ubicación denegados');
          return _ultimaUbicacionCache;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LocationService] Permisos denegados permanentemente');
        return _ultimaUbicacionCache;
      }

      // Primero intentar obtener última ubicación conocida rápidamente
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && lastKnown.accuracy <= 50) {
        print('[LocationService] Usando última ubicación conocida (±${lastKnown.accuracy.toStringAsFixed(1)}m)');
        _actualizarCache(lastKnown);
        return lastKnown;
      }

      // Obtener ubicación con configuración consistente
      final position = await Geolocator.getCurrentPosition(
        locationSettings:  AndroidSettings(
          accuracy: LocationAccuracy.best, // SIEMPRE usar 'best' para consistencia
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: Duration(milliseconds: 500),
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[LocationService] Timeout - usando última conocida');
          return lastKnown ?? _ultimaUbicacionCache!;
        },
      );

      print('[LocationService] Ubicación obtenida: ${position.latitude}, ${position.longitude} (±${position.accuracy.toStringAsFixed(1)}m)');

      _actualizarCache(position);
      return position;
    } catch (e) {
      print('[LocationService] Error obteniendo ubicación: $e');
      return _ultimaUbicacionCache;
    }
  }

  /// Actualizar cache interno
  void _actualizarCache(Position position) {
    _ultimaUbicacionCache = position;
    _tiempoUltimaUbicacion = DateTime.now();
  }

  /// Limpiar cache (útil cuando se necesita forzar actualización)
  void limpiarCache() {
    _ultimaUbicacionCache = null;
    _tiempoUltimaUbicacion = null;
  }

  /// Obtener ubicación de MÁXIMA PRECISIÓN (para geolocalizar clientes)
  Future<Position?> obtenerUbicacionPrecisa({
    Function(double accuracy)? onProgress,
    double precisionObjetivo = 5.0, // metros
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[LocationService] Servicio deshabilitado');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      Position? mejorPosicion;
      final startTime = DateTime.now();
      final completer = Completer<Position?>();

      final stream = Geolocator.getPositionStream(
        locationSettings:  AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: Duration(milliseconds: 500),
        ),
      );

      StreamSubscription<Position>? subscription;

      subscription = stream.listen(
            (position) {
          final elapsed = DateTime.now().difference(startTime);

          onProgress?.call(position.accuracy);

          if (mejorPosicion == null || position.accuracy < mejorPosicion!.accuracy) {
            mejorPosicion = position;
            print('[LocationService] Mejorando precisión: ${position.accuracy.toStringAsFixed(1)}m');
          }

          // Si alcanzamos la precisión objetivo o se acabó el tiempo
          if (position.accuracy <= precisionObjetivo || elapsed >= timeout) {
            subscription?.cancel();
            if (!completer.isCompleted) {
              if (mejorPosicion != null) {
                _actualizarCache(mejorPosicion!);
              }
              completer.complete(mejorPosicion);
            }
          }
        },
        onError: (error) {
          print('[LocationService] Error en stream: $error');
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(mejorPosicion);
          }
        },
      );

      // Timeout de seguridad
      Future.delayed(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(mejorPosicion);
        }
      });

      return completer.future;
    } catch (e) {
      print('[LocationService] Error: $e');
      return null;
    }
  }

  /// Obtener última ubicación conocida (instantáneo)
  Future<Position?> obtenerUltimaUbicacionConocida() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('[LocationService] Error obteniendo última ubicación: $e');
      return null;
    }
  }

  /// Stream de ubicación para seguimiento en tiempo real
  Stream<Position> obtenerStreamUbicacion({
    LocationAccuracy accuracy = LocationAccuracy.best, // Cambiado a 'best'
    int distanceFilter = 5, // Reducido para más actualizaciones
  }) {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1), // Más frecuente
      ),
    );
  }

  /// Calcular distancia entre dos puntos (en metros)
  double calcularDistancia({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Verificar si los permisos están habilitados
  Future<bool> tienePermisoUbicacion() async {
    final permiso = await Geolocator.checkPermission();
    return permiso == LocationPermission.whileInUse ||
        permiso == LocationPermission.always;
  }

  /// Verificar si el servicio de ubicación está habilitado
  Future<bool> servicioUbicacionHabilitado() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Abrir configuración de ubicación del dispositivo
  Future<bool> abrirConfiguracionUbicacion() async {
    return await Geolocator.openLocationSettings();
  }

  /// Abrir configuración de permisos de la app
  Future<bool> abrirConfiguracionApp() async {
    return await Geolocator.openAppSettings();
  }
}