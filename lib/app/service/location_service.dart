import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// Obtener ubicación RÁPIDA con buena precisión (uso general)
  Future<Position?> obtenerUbicacionActual() async {
    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[LocationService] Servicio de ubicación deshabilitado');
        return null;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[LocationService] Permisos de ubicación denegados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LocationService] Permisos denegados permanentemente');
        await Geolocator.openLocationSettings();
        return null;
      }

      // Obtener ubicación con buena precisión pero sin demoras excesivas
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high, // Cambiado de 'best' a 'high' para ser más rápido
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 1000),
        ),
      ).timeout(const Duration(seconds: 8)); // Timeout reducido

      print('[LocationService] Ubicación obtenida: ${position.latitude}, ${position.longitude} (±${position.accuracy.toStringAsFixed(1)}m)');

      return position;
    } catch (e) {
      print('[LocationService] Error obteniendo ubicación: $e');
      return null;
    }
  }

  /// Obtener ubicación de MÁXIMA PRECISIÓN (solo cuando sea crítico)
  Future<Position?> obtenerUbicacionPrecisa({
    Function(double accuracy)? onProgress,
    double precisionObjetivo = 8.0, // metros
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      Position? mejorPosicion;
      final startTime = DateTime.now();

      // Usar stream para obtener actualizaciones continuas hasta alcanzar precisión deseada
      final completer = Completer<Position?>();

      final stream = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 500),
        ),
      );

      StreamSubscription<Position>? subscription;

      subscription = stream.listen(
            (position) {
          final elapsed = DateTime.now().difference(startTime);

          onProgress?.call(position.accuracy);

          if (mejorPosicion == null || position.accuracy < mejorPosicion!.accuracy) {
            mejorPosicion = position;
            print('[LocationService] Nueva mejor precisión: ${position.accuracy.toStringAsFixed(1)}m');
          }

          // Si alcanzamos la precisión objetivo o se acabó el tiempo
          if (position.accuracy <= precisionObjetivo || elapsed >= timeout) {
            subscription?.cancel();
            if (!completer.isCompleted) {
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
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 2),
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

/////////////////este es el bueno