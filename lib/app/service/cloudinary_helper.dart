import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CloudinaryHelper {
  // Reemplaza estos con tus credenciales de Cloudinary
  static const String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dsaopttmq/image/upload';
  static const String uploadPreset = 'app_bodega';

  // Para eliminar imágenes necesitas estas credenciales
  static const String cloudName = 'dsaopttmq';
  static const String apiKey = '345979946123959';
  static const String apiSecret = 'G3NRRLu5hKgzyEuk92szR8t7zuw';

  Future<String?> subirImagenProducto(File imagen) async {
    try {
      print('📤 Iniciando carga a Cloudinary...');

      final uri = Uri.parse(cloudinaryUrl);
      final request = http.MultipartRequest('POST', uri);

      // Agregar archivo
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagen.path,
        ),
      );

      // Agregar upload preset
      request.fields['upload_preset'] = uploadPreset;

      // Opcional: agregar tags para organizar
      request.fields['tags'] = 'app-bodega-producto';

      // Enviar solicitud
      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);

      if (response.statusCode == 200) {
        // Parsear la respuesta JSON
        final Map<String, dynamic> jsonResponse =
        _parseJson(responseString);

        final imageUrl = jsonResponse['secure_url'] ?? jsonResponse['url'];

        if (imageUrl != null) {
          return imageUrl;
        } else {
          print('❌ No se encontró URL en respuesta');
          return null;
        }
      } else {
        print('❌ Error: ${response.statusCode}');
        print('Respuesta: $responseString');
        return null;
      }
    } catch (e) {
      print('❌ Error al subir a Cloudinary: $e');
      return null;
    }
  }

  // Método simple para parsear JSON sin dependencias adicionales
  static Map<String, dynamic> _parseJson(String jsonString) {
    final map = <String, dynamic>{};

    // Extraer secure_url
    final secureUrlRegex = RegExp(r'"secure_url":"([^"]+)"');
    final secureUrlMatch = secureUrlRegex.firstMatch(jsonString);
    if (secureUrlMatch != null) {
      map['secure_url'] = secureUrlMatch.group(1);
    }

    // Extraer url
    final urlRegex = RegExp(r'"url":"([^"]+)"');
    final urlMatch = urlRegex.firstMatch(jsonString);
    if (urlMatch != null) {
      map['url'] = urlMatch.group(1);
    }

    // Extraer public_id
    final publicIdRegex = RegExp(r'"public_id":"([^"]+)"');
    final publicIdMatch = publicIdRegex.firstMatch(jsonString);
    if (publicIdMatch != null) {
      map['public_id'] = publicIdMatch.group(1);
    }

    return map;
  }

  // Método para eliminar imagen de Cloudinary
  Future<bool> eliminarImagen(String publicId) async {
    try {

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      // Crear la firma necesaria para autenticación
      final cadenaFirma = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(cadenaFirma)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');

      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Error al eliminar: ${response.statusCode}');
        print('Respuesta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }
}