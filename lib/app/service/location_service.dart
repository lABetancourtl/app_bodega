import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// Obtener ubicación actual con configuración optimizada
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

      // Obtener ubicación con configuración mejorada
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0, // Sin caché, siempre ubicación fresca
          timeLimit: Duration(seconds: 15), // Timeout de 15 segundos
        ),
      );
    } catch (e) {
      print('[LocationService] Error obteniendo ubicación: $e');
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

  /// Stream de ubicación en tiempo real para seguimiento
  Stream<Position> obtenerStreamUbicacion({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // Actualizar cada 10 metros
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: const Duration(seconds: 10),
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