package com.docdoctor.doc_doctor

import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "doc_doctor/intents"
    private var channel: MethodChannel? = null
    private var pendingIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> result.success(consumeSharedFiles())
                "openFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val ok = openFile(path)
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("open_failed", e.message, null)
                    }
                }
                "openFolder" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val ok = openFolder(path)
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("open_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type
        val isShare = action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE
        val isView = action == Intent.ACTION_VIEW
        if (!isShare && !isView) return
        if (isView && intent.data == null) return
        pendingIntent = intent
        channel?.invokeMethod("onSharedFiles", consumeSharedFiles())
    }

    private fun consumeSharedFiles(): HashMap<String, Any?> {
        val intent = pendingIntent ?: return hashMapOf()
        val data = hashMapOf<String, Any?>()
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            val uri = intent.data
            data["files"] = listOf(mapOf(
                "path" to copyUriToCache(uri),
                "name" to queryDisplayName(uri),
                "mime" to (uri?.let { contentResolver.getType(it) } ?: "")
            ))
            data["action"] = "view"
            return data
        }
        if (intent.action == Intent.ACTION_SEND) {
            val uri = intent.getParcelableExtra<Parcelable?>(Intent.EXTRA_STREAM) as? Uri
            if (uri != null) {
                data["files"] = listOf(mapOf(
                    "path" to copyUriToCache(uri),
                    "name" to queryDisplayName(uri),
                    "mime" to (contentResolver.getType(uri) ?: "")
                ))
            }
            data["text"] = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
            data["action"] = "send"
        }
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val uris = intent.getParcelableArrayListExtra<Parcelable?>(Intent.EXTRA_STREAM)
            val files = mutableListOf<Map<String, String>>()
            if (uris != null) {
                for (u in uris) {
                    val uri = u as? Uri ?: continue
                    files.add(mapOf(
                        "path" to copyUriToCache(uri),
                        "name" to queryDisplayName(uri),
                        "mime" to (contentResolver.getType(uri) ?: "")
                    ))
                }
            }
            data["files"] = files
            data["action"] = "send"
        }
        data["type"] = intent.type ?: ""
        pendingIntent = null
        return data
    }

    private fun copyUriToCache(uri: Uri?): String {
        if (uri == null) return ""
        val resolver: ContentResolver = contentResolver
        return try {
            val name = queryDisplayName(uri)
            val safeName = if (name.isNullOrBlank()) {
                "shared_${System.currentTimeMillis()}" +
                    (MimeTypeMap.getSingleton().getExtensionFromMimeType(resolver.getType(uri) ?: "")?.let { ".$it" } ?: "")
            } else name
            val dir = File(cacheDir, "shared_in")
            dir.mkdirs()
            val outFile = File(dir, safeName)
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
            }
            outFile.absolutePath
        } catch (e: Exception) {
            ""
        }
    }

        private fun queryDisplayName(uri: Uri?): String {
            if (uri == null) return ""
            if (uri.scheme == "file") return File(uri.path ?: "").name
            var name = ""
            try {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) name = it.getString(idx) ?: ""
                    }
                }
            } catch (e: Exception) {
                // ignore
            }
            return name
        }

        private fun uriFor(file: File): Uri =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
                } catch (e: IllegalArgumentException) {
                    Uri.fromFile(file)
                }
            } else {
                Uri.fromFile(file)
            }

        private fun mimeForFile(file: File): String {
            val ext = file.extension.lowercase()
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            return mime ?: "*/*"
        }

        private fun openFile(path: String): Boolean {
            val file = File(path)
            if (!file.exists() || !file.isFile) return false
            val uri = uriFor(file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeForFile(file))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "Open with").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null || chooser.resolveActivity(packageManager) != null) {
                startActivity(chooser)
                return true
            }
            return false
        }

        private fun openFolder(path: String): Boolean {
            val dir = File(path)
            if (!dir.exists() || !dir.isDirectory) return false
            val uri = uriFor(dir)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "vnd.android.document/directory")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
            intent.setDataAndType(uri, "*/*")
            val chooser = Intent.createChooser(intent, "Open in file manager").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (chooser.resolveActivity(packageManager) != null) {
                startActivity(chooser)
                return true
            }
            return false
        }
    }
