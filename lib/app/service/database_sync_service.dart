// import 'dart:io';
//
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:sqflite/sqflite.dart';
//
// import '../datasources/database_helper.dart';
//
// class DatabaseSyncService {
//   static const String dbFileName = 'app_pedidos.db';
//   static const platform = MethodChannel('com.bodega.app/filepicker');
//
//   // Exportar base de datos
//   static Future<void> exportarBaseDatos() async {
//     try {
//       // Obtener la ruta de la BD
//       final databasesPath = await getDatabasesPath();
//       final dbPath = '$databasesPath/$dbFileName';
//       final dbFile = File(dbPath);
//
//       if (!dbFile.existsSync()) {
//         throw Exception('Base de datos no encontrada');
//       }
//
//       final downloadsDir = await getApplicationDocumentsDirectory();
//
//       // Eliminar respaldos anteriores PRIMERO
//       await _eliminarTodosLosRespaldos();
//
//       // Crear el nuevo respaldo con timestamp
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final exportPath = '${downloadsDir.path}/bodega_backup_$timestamp.db';
//       await dbFile.copy(exportPath);
//
//       // Compartir archivo
//       await Share.shareXFiles(
//         [XFile(exportPath, mimeType: 'application/octet-stream')],
//         text: 'Respaldo de Base de Datos - App Bodega',
//         subject: 'bodega_backup_$timestamp.db',
//       );
//     } catch (e) {
//       throw Exception('Error al exportar: $e');
//     }
//   }
//
//   // Eliminar todos los respaldos existentes
//   static Future<void> _eliminarTodosLosRespaldos() async {
//     try {
//       final downloadsDir = await getApplicationDocumentsDirectory();
//       final dir = Directory(downloadsDir.path);
//
//       if (!dir.existsSync()) {
//         return;
//       }
//
//       final files = dir.listSync();
//       final backups = files
//           .whereType<File>()
//           .where((file) => file.path.contains('bodega_backup_'))
//           .toList();
//
//       // Eliminar todos los respaldos
//       for (var backup in backups) {
//         try {
//           await backup.delete();
//         } catch (e) {
//           // Ignorar errores al eliminar
//         }
//       }
//     } catch (e) {
//       // Ignorar errores
//     }
//   }
//
//   // Seleccionar archivo manualmente usando Intent
//   static Future<String?> seleccionarArchivoManual() async {
//     try {
//       final String result = await platform.invokeMethod('selectFile');
//       return result;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   // Importar base de datos desde el archivo seleccionado
//   static Future<bool> importarBaseDatos(String rutaArchivo) async {
//     try {
//       final archivoSeleccionado = File(rutaArchivo);
//
//       if (!archivoSeleccionado.existsSync()) {
//         throw Exception('Archivo no encontrado');
//       }
//
//       // Obtener rutas
//       final databasesPath = await getDatabasesPath();
//       final dbPath = '$databasesPath/$dbFileName';
//       final dbFile = File(dbPath);
//
//       // Hacer backup del archivo actual (por si acaso)
//       if (dbFile.existsSync()) {
//         final backupPath = '$databasesPath/${dbFileName}_backup_antiguo';
//         await dbFile.copy(backupPath);
//       }
//
//       // Reemplazar con el nuevo archivo
//       await archivoSeleccionado.copy(dbPath);
//
//       // Cerrar conexión anterior
//       final dbHelper = DatabaseHelper();
//       await dbHelper.close();
//
//       // Resetear la instancia singleton
//       DatabaseHelper.resetearConexion();
//
//       return true;
//     } catch (e) {
//       throw Exception('Error al importar: $e');
//     }
//   }
//
//   // Obtener información de la BD actual
//   static Future<Map<String, dynamic>> obtenerInfoBaseDatos() async {
//     try {
//       final databasesPath = await getDatabasesPath();
//       final dbPath = '$databasesPath/$dbFileName';
//       final dbFile = File(dbPath);
//
//       if (!dbFile.existsSync()) {
//         return {'existe': false, 'tamaño': 0};
//       }
//
//       final stat = dbFile.statSync();
//       final tamano = stat.size / 1024; // En KB
//
//     return {
//     'existe': true,
//     'tamaño': '${tamano.toStringAsFixed(2)} KB',
//     'ruta': dbPath,
//     };
//     } catch (e) {
//     return {'existe': false, 'error': e.toString()};
//     }
//   }
//
//   // Listar archivos de respaldo disponibles
//   static Future<List<FileSystemEntity>> obtenerBackupsDisponibles() async {
//     try {
//       final downloadsDir = await getApplicationDocumentsDirectory();
//       final dir = Directory(downloadsDir.path);
//
//       if (!dir.existsSync()) {
//         return [];
//       }
//
//       final files = dir.listSync();
//       final backups = files
//           .where((file) =>
//       file.path.contains('bodega_backup_') &&
//           !file.path.contains('temp') &&
//           FileSystemEntity.isFileSync(file.path))
//           .toList();
//
//       return backups;
//     } catch (e) {
//       return [];
//     }
//   }
// }