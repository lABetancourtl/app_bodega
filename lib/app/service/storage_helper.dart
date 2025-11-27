import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageHelper {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Sube una imagen de producto y retorna la URL
  Future<String> subirImagenProducto(File imagen) async {
    try {
      // Generar nombre único: timestamp_nombreOriginal
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imagen.path)}';
      final ref = _storage.ref().child('productos/$fileName');

      // Subir archivo
      final uploadTask = await ref.putFile(imagen);

      // Obtener URL de descarga
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  /// Elimina una imagen del Storage usando su URL
  Future<void> eliminarImagen(String imageUrl) async {
    try {
      // Extraer referencia de la URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error al eliminar imagen: $e');
      // No lanzar excepción, solo log
    }
  }

  /// Actualiza imagen: elimina la anterior y sube la nueva
  Future<String> actualizarImagenProducto(String? imagenAnteriorUrl, File nuevaImagen) async {
    // Eliminar imagen anterior si existe
    if (imagenAnteriorUrl != null && imagenAnteriorUrl.isNotEmpty) {
      await eliminarImagen(imagenAnteriorUrl);
    }

    // Subir nueva imagen
    return await subirImagenProducto(nuevaImagen);
  }
}