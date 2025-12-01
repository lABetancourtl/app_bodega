import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// Obtener ubicación actual del dispositivo
  Future<Position?> obtenerUbicacionActual() async {
    try {
      final permisoLoc = await Geolocator.checkPermission();

      if (permisoLoc == LocationPermission.denied) {
        final permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          return null;
        }
      }

      if (permisoLoc == LocationPermission.deniedForever) {
        await Geolocator.openLocationSettings();
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('[v0] Error obteniendo ubicación: $e');
      return null;
    }
  }

  /// Verificar si los permisos de ubicación están habilitados
  Future<bool> tienePermisoUbicacion() async {
    final permiso = await Geolocator.checkPermission();
    return permiso == LocationPermission.whileInUse ||
        permiso == LocationPermission.always;
  }
}
