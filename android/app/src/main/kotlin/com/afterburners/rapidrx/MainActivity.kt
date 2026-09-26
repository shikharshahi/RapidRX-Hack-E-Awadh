package com.afterburners.rapidrx

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Backup mirror at Documents/RapidRX. Android 10+ uses MediaStore, so the
/// app does not request MANAGE_EXTERNAL_STORAGE. Older phones keep the same
/// names under app-specific storage, which does not survive uninstall.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(readBackup())
                    "write" -> {
                        val vault = call.argument<ByteArray>("vault")
                        val manifest = call.argument<String>("manifest")
                        if (vault == null || manifest == null) {
                            result.error("bad", "missing", null)
                        } else {
                            writeBackup(vault, manifest)
                            result.success(null)
                        }
                    }
                    "delete" -> {
                        deleteBackup()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readBackup(): Map<String, Any>? {
        val vault = readNamed(VAULT) ?: return null
        val manifest = readNamed(MANIFEST) ?: return null
        return mapOf("vault" to vault, "manifest" to String(manifest, Charsets.UTF_8))
    }

    private fun writeBackup(vault: ByteArray, manifest: String) {
        writeNamed(VAULT, "application/octet-stream", vault)
        writeNamed(MANIFEST, "application/json", manifest.toByteArray(Charsets.UTF_8))
    }

    private fun deleteBackup() {
        deleteNamed(VAULT)
        deleteNamed(MANIFEST)
    }

    private fun writeNamed(name: String, mime: String, bytes: ByteArray) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            deleteNamed(name)
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                values,
            ) ?: return
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } else {
            val file = legacyFile(name)
            file.parentFile?.mkdirs()
            file.writeBytes(bytes)
        }
    }

    private fun readNamed(name: String): ByteArray? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection =
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            val args = arrayOf(name, "%RapidRX%")
            resolver.query(uri, projection, selection, args, null)?.use { cursor ->
                val id = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                if (!cursor.moveToFirst()) return null
                val item = android.content.ContentUris.withAppendedId(uri, cursor.getLong(id))
                return resolver.openInputStream(item)?.use { it.readBytes() }
            }
            return null
        }
        val file = legacyFile(name)
        return if (file.exists()) file.readBytes() else null
    }

    private fun deleteNamed(name: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val selection =
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            resolver.delete(uri, selection, arrayOf(name, "%RapidRX%"))
        } else {
            val file = legacyFile(name)
            if (file.exists()) file.delete()
        }
    }

    private fun legacyFile(name: String): File {
        val dir = applicationContext.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
        return File(dir, "RapidRX/$name")
    }

    companion object {
        private const val CHANNEL = "rapidrx/record_backup"
        private const val RELATIVE = "Documents/RapidRX/"
        private const val VAULT = "records.vault"
        private const val MANIFEST = "manifest.json"
    }
}
