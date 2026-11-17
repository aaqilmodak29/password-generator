package com.aaqilmodak.passwordgenerator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

class MainActivity: FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    // A file shared into the app, held until Dart asks for it.
    private var pending: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        if (savedInstanceState == null) receive(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takePending") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receive(intent)
        if (pending != null) channel?.invokeMethod("received", null)
    }

    // Read the file straight away: the URI grant from the sharing app doesn't last.
    private fun receive(intent: Intent?) {
        val uri = when (intent?.action) {
            Intent.ACTION_SEND -> streamOf(intent)
            Intent.ACTION_VIEW -> intent.data
            else -> null
        } ?: return

        val name = displayName(uri)
        pending = try {
            val bytes = contentResolver.openInputStream(uri)?.use { readCapped(it) }
            when {
                bytes == null -> mapOf("name" to name, "error" to "Couldn't open $name.")
                bytes.size > MAX_BYTES -> mapOf("name" to name, "error" to "$name is too large to be a backup.")
                else -> mapOf("name" to name, "bytes" to bytes)
            }
        } catch (e: Exception) {
            Log.w(TAG, "reading shared file failed", e)
            mapOf("name" to name, "error" to "Couldn't read $name.")
        }
    }

    @Suppress("DEPRECATION")
    private fun streamOf(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun displayName(uri: Uri): String =
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { if (it.moveToFirst()) it.getString(0) else null }
        } catch (e: Exception) {
            null
        } ?: uri.lastPathSegment ?: "shared file"

    // Stops one byte past the cap so an oversized file is caught without reading all of it.
    private fun readCapped(input: InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buf = ByteArray(8192)
        while (out.size() <= MAX_BYTES) {
            val n = input.read(buf)
            if (n < 0) break
            out.write(buf, 0, n)
        }
        return out.toByteArray()
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.aaqilmodak.passwordgenerator/shared_backup"
        private const val MAX_BYTES = 10 * 1024 * 1024
    }
}
