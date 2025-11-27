// import 'dart:io';
//
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../service/database_sync_service.dart';
//
// class BackupPage extends StatefulWidget {
//   const BackupPage({super.key});
//
//   @override
//   State<BackupPage> createState() => _BackupPageState();
// }
//
// class _BackupPageState extends State<BackupPage> {
//   Map<String, dynamic> infoBaseDatos = {};
//   List<FileSystemEntity> backupsDisponibles = [];
//   bool cargando = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _cargarInfo();
//     _cargarBackups();
//   }
//
//   void _cargarInfo() async {
//     final info = await DatabaseSyncService.obtenerInfoBaseDatos();
//     setState(() {
//       infoBaseDatos = info;
//     });
//   }
//
//   void _cargarBackups() async {
//     final backups = await DatabaseSyncService.obtenerBackupsDisponibles();
//     setState(() {
//       // Filtrar solo archivos que existen
//       backupsDisponibles = backups
//           .whereType<File>()
//           .where((file) => file.existsSync())
//           .toList();
//     });
//   }
//
//   void _exportar() async {
//     setState(() => cargando = true);
//     try {
//       await DatabaseSyncService.exportarBaseDatos();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Base de datos exportada correctamente'),
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//       _cargarBackups();
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error: $e'),
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } finally {
//       setState(() => cargando = false);
//     }
//   }
//
//   void _seleccionarArchivoManual() async {
//     setState(() => cargando = true);
//     try {
//       final rutaArchivo =
//       await DatabaseSyncService.seleccionarArchivoManual();
//       if (rutaArchivo != null) {
//         _importarBackup(File(rutaArchivo));
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error al seleccionar archivo: $e')),
//         );
//       }
//     } finally {
//       setState(() => cargando = false);
//     }
//   }
//
//   void _importarBackup(File archivo) async {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Importar Base de Datos'),
//         content: const Text(
//           '⚠️ Esto reemplazará todos tus datos actuales con los del archivo seleccionado.\n\nSe hará un respaldo automático del archivo actual.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancelar'),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               setState(() => cargando = true);
//               try {
//                 final resultado =
//                 await DatabaseSyncService.importarBaseDatos(archivo.path);
//                 if (resultado && mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('✅ Base de datos importada correctamente'),
//                       duration: Duration(seconds: 2),
//                     ),
//                   );
//                   _cargarInfo();
//                 }
//               } catch (e) {
//                 if (mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('❌ Error: $e'),
//                       duration: const Duration(seconds: 3),
//                     ),
//                   );
//                 }
//               } finally {
//                 setState(() => cargando = false);
//               }
//             },
//             child: const Text('Importar', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _obtenerNombreArchivo(String ruta) {
//     return ruta.split('/').last;
//   }
//
//   String _obtenerTamanoArchivo(File file) {
//     try {
//       if (!file.existsSync()) {
//         return 'No disponible';
//       }
//       final bytes = file.lengthSync();
//       if (bytes < 1024) {
//         return '$bytes B';
//       } else if (bytes < 1024 * 1024) {
//         return '${(bytes / 1024).toStringAsFixed(2)} KB';
//       } else {
//         return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
//       }
//     } catch (e) {
//       return 'Error';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Respaldo y Sincronización'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Información actual
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Estado de la Base de Datos',
//                       style:
//                       TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 12),
//                     if (infoBaseDatos['existe'] == true)
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               const Icon(Icons.check_circle,
//                                   color: Colors.green),
//                               const SizedBox(width: 8),
//                               const Text('Base de datos: '),
//                               Text(
//                                 'Existe',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.green[700],
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Tamaño: ${infoBaseDatos['tamaño'] ?? 'Desconocido'}',
//                             style: const TextStyle(fontSize: 14),
//                           ),
//                         ],
//                       )
//                     else
//                       Row(
//                         children: [
//                           const Icon(Icons.error, color: Colors.red),
//                           const SizedBox(width: 8),
//                           const Text('Base de datos: '),
//                           Text(
//                             'No encontrada',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               color: Colors.red[700],
//                             ),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//             // Importar manualmente desde cualquier ubicación
//             const Text(
//               'Importar Base de Datos',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: cargando ? null : _seleccionarArchivoManual,
//                 icon: const Icon(Icons.folder_open),
//                 label: const Text('Seleccionar Archivo'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.orange,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   disabledBackgroundColor: Colors.grey,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//             // Opciones de exportación
//             const Text(
//               'Exportar Base de Datos',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: cargando ? null : _exportar,
//                 icon: const Icon(Icons.cloud_download),
//                 label: const Text('Crear Respaldo'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   disabledBackgroundColor: Colors.grey,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//             // Backups disponibles
//             const Text(
//               'Respaldos Disponibles',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             if (backupsDisponibles.isEmpty)
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Center(
//                   child: Text(
//                     'No hay respaldos disponibles',
//                     style: TextStyle(color: Colors.grey),
//                   ),
//                 ),
//               )
//             else
//               ListView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: backupsDisponibles.length,
//                 itemBuilder: (context, index) {
//                   final backup = backupsDisponibles[index];
//                   final file = File(backup.path);
//
//                   // Validar que el archivo existe
//                   if (!file.existsSync()) {
//                     return const SizedBox.shrink();
//                   }
//
//                   final nombre = _obtenerNombreArchivo(backup.path);
//                   final tamano = _obtenerTamanoArchivo(file);
//
//                   return Card(
//                     margin: const EdgeInsets.only(bottom: 8),
//                     child: ListTile(
//                       leading:
//                       const Icon(Icons.backup, color: Colors.orange),
//                       title: Text(nombre),
//                       subtitle: Text(tamano),
//                       trailing: IconButton(
//                         icon: const Icon(Icons.restore, color: Colors.blue),
//                         onPressed: cargando
//                             ? null
//                             : () => _importarBackup(file),
//                         tooltip: 'Restaurar',
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             const SizedBox(height: 24),
//             if (cargando) ...[
//               const SizedBox(height: 24),
//               const Center(
//                 child: Column(
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 16),
//                     Text('Procesando...'),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }