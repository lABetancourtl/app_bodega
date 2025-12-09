import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// <CHANGE> Obtener ubicación con MÁXIMA precisión posible
  /// Toma múltiples lecturas y devuelve la más precisa
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

      // <CHANGE> Obtener múltiples lecturas y seleccionar la más precisa
      Position? mejorPosicion;
      const int maxIntentos = 3;
      const double precisionAceptable = 10.0; // metros

      for (int i = 0; i < maxIntentos; i++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.best, // <CHANGE> Máxima precisión
              distanceFilter: 0,
              forceLocationManager: false,
              intervalDuration: const Duration(milliseconds: 500),
              useMSLAltitude: false,
            ),
          ).timeout(const Duration(seconds: 10));

          print('[LocationService] Lectura ${i + 1}: accuracy=${position.accuracy}m');

          // Si es la primera lectura o es más precisa que la anterior
          if (mejorPosicion == null || position.accuracy < mejorPosicion.accuracy) {
            mejorPosicion = position;
          }

          // Si ya tenemos una precisión aceptable, salir del loop
          if (position.accuracy <= precisionAceptable) {
            print('[LocationService] Precisión aceptable alcanzada: ${position.accuracy}m');
            break;
          }

          // Esperar un poco antes de la siguiente lectura
          if (i < maxIntentos - 1) {
            await Future.delayed(const Duration(milliseconds: 800));
          }
        } catch (e) {
          print('[LocationService] Error en lectura ${i + 1}: $e');
        }
      }

      if (mejorPosicion != null) {
        print('[LocationService] Mejor ubicación: ${mejorPosicion.latitude}, ${mejorPosicion.longitude} (±${mejorPosicion.accuracy.toStringAsFixed(1)}m)');
      }

      return mejorPosicion;
    } catch (e) {
      print('[LocationService] Error obteniendo ubicación: $e');
      return null;
    }
  }

  /// <CHANGE> Nueva función para obtener ubicación de alta precisión con callback de progreso
  Future<Position?> obtenerUbicacionPrecisa({
    Function(double accuracy)? onProgress,
    double precisionObjetivo = 8.0, // metros
    Duration timeout = const Duration(seconds: 20),
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

  /// Obtener última ubicación conocida (más rápido pero puede ser antigua)
  Future<Position?> obtenerUltimaUbicacionConocida() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('[LocationService] Error obteniendo última ubicación: $e');
      return null;
    }
  }

  /// <CHANGE> Stream de ubicación con máxima precisión para seguimiento en tiempo real
  Stream<Position> obtenerStreamUbicacion({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 5, // <CHANGE> Actualizar cada 5 metros para más precisión
  }) {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
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