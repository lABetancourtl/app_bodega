
package com.bodega.app_bodega

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bodega.app/filepicker"
    private val REQUEST_CODE = 100
    private var methodResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectFile" -> {
                        methodResult = result
                        selectFile()
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun selectFile() {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.type = "*/*"
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        startActivityForResult(intent, REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE && resultCode == Activity.RESULT_OK) {
            val uri: Uri? = data?.data
            if (uri != null) {
                val path = getRealPathFromURI(uri)
                methodResult?.success(path)
            } else {
                methodResult?.error("NO_FILE", "No file selected", null)
            }
        } else {
            methodResult?.error("CANCELLED", "User cancelled", null)
        }
        methodResult = null
    }

    private fun getRealPathFromURI(uri: Uri): String {
        return try {
            // Obtener el nombre del archivo
            val fileName = getFileName(uri)

            // Crear archivo temporal en la carpeta caché de la app
            val inputStream = contentResolver.openInputStream(uri)
            val cacheDir = cacheDir
            val tempFile = java.io.File(cacheDir, fileName ?: "backup_${System.currentTimeMillis()}.db")

            inputStream?.use { input ->
                tempFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            tempFile.absolutePath
        } catch (e: Exception) {
            uri.path ?: ""
        }
    }

    private fun getFileName(uri: Uri): String? {
        return when {
            uri.scheme == "content" -> {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    val nameIndex = it.getColumnIndex("_display_name")
                    if (nameIndex != -1) {
                        it.moveToFirst()
                        it.getString(nameIndex)
                    } else {
                        null
                    }
                }
            }
            uri.scheme == "file" -> uri.lastPathSegment
            else -> null
        }
    }
}