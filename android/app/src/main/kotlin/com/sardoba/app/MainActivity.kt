package com.sardobabukhara.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability

class MainActivity : FlutterActivity() {
    private var appUpdateManager: AppUpdateManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appUpdateManager = AppUpdateManagerFactory.create(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppInfo" -> getAppInfo(result)
                "checkForUpdate" -> checkForUpdate(result)
                "startImmediateUpdate" -> startImmediateUpdate(result)
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun installedAppVersion(): String {
        return packageManager.getPackageInfo(packageName, 0).versionName
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: throw IllegalStateException("Installed app version is unavailable")
    }

    private fun getAppInfo(result: MethodChannel.Result) {
        try {
            result.success(
                mapOf("version" to installedAppVersion(), "platform" to "android")
            )
        } catch (_: Exception) {
            result.error(
                "APP_VERSION_UNAVAILABLE",
                "Installed app version is unavailable",
                null
            )
        }
    }

    override fun onResume() {
        super.onResume()
        appUpdateManager?.appUpdateInfo?.addOnSuccessListener { info ->
            if (info.updateAvailability() ==
                UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
            ) {
                launchImmediateUpdate(info)
            }
        }
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        val manager = appUpdateManager
        if (manager == null) {
            result.success(mapOf("updateAvailable" to false))
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                val available = info.updateAvailability() ==
                    UpdateAvailability.UPDATE_AVAILABLE ||
                    info.updateAvailability() ==
                    UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                result.success(mapOf("updateAvailable" to available))
            }
            .addOnFailureListener {
                // A Play services outage or a sideloaded build must not block startup.
                result.success(mapOf("updateAvailable" to false))
            }
    }

    private fun startImmediateUpdate(result: MethodChannel.Result) {
        val manager = appUpdateManager
        if (manager == null) {
            result.error("UPDATE_UNAVAILABLE", "Google Play update service is unavailable", null)
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                if (info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                    if (launchImmediateUpdate(info)) {
                        result.success(true)
                    } else {
                        result.error("UPDATE_START_FAILED", "Google Play update could not start", null)
                    }
                } else {
                    result.error("UPDATE_UNAVAILABLE", "Immediate update is unavailable", null)
                }
            }
            .addOnFailureListener { error ->
                result.error("UPDATE_CHECK_FAILED", error.message, null)
            }
    }

    private fun launchImmediateUpdate(
        info: com.google.android.play.core.appupdate.AppUpdateInfo
    ): Boolean {
        return try {
            appUpdateManager?.startUpdateFlowForResult(
                info,
                this,
                AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                UPDATE_REQUEST_CODE
            ) ?: false
        } catch (_: android.content.IntentSender.SendIntentException) {
            false
        }
    }

    companion object {
        private const val UPDATE_CHANNEL = "com.sardoba/app_update"
        private const val UPDATE_REQUEST_CODE = 7201
    }
}
