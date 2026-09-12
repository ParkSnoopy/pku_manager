package com.parksnoopy.pku_manager

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingAppDataResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appDataChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != pickAppDataMethod) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingAppDataResult != null) {
                result.error("busy", "Another app data selection is active.", null)
                return@setMethodCallHandler
            }
            pendingAppDataResult = result
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            try {
                @Suppress("DEPRECATION")
                startActivityForResult(intent, appDataRequestCode)
            } catch (error: Exception) {
                pendingAppDataResult = null
                result.error("open_failed", "App data selection could not start.", null)
            }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != appDataRequestCode) return
        val result = pendingAppDataResult ?: return
        pendingAppDataResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val cached = File(cacheDir, "app-data-import-${System.nanoTime()}.pkudata")
        Thread({
            try {
                val input = contentResolver.openInputStream(uri)
                    ?: throw IllegalArgumentException("Selected app data could not be opened.")
                input.use { stream ->
                    cached.outputStream().buffered().use { output ->
                        val buffer = ByteArray(8192)
                        var total = 0
                        while (true) {
                            val count = stream.read(buffer)
                            if (count < 0) break
                            total += count
                            if (total > maxAppDataBytes) {
                                cached.delete()
                                runOnUiThread {
                                    result.error(
                                        "too_large",
                                        "App data exceeds the size limit.",
                                        null,
                                    )
                                }
                                return@Thread
                            }
                            output.write(buffer, 0, count)
                        }
                    }
                }
                runOnUiThread { result.success(cached.absolutePath) }
            } catch (error: Exception) {
                cached.delete()
                runOnUiThread {
                    result.error("read_failed", "Selected app data could not be read.", null)
                }
            }
        }, "pku-app-data-import").start()
    }

    companion object {
        private const val appDataChannel = "com.parksnoopy.pku_manager/app_data"
        private const val pickAppDataMethod = "pickAppData"
        private const val appDataRequestCode = 7418
        private const val maxAppDataBytes = 256 * 1024 * 1024
    }
}
