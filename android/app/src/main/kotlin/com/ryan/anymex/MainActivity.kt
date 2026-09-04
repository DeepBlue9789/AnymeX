package com.ryan.anymex

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Rational
import android.view.KeyEvent
import android.view.KeyEvent.ACTION_DOWN
import android.view.KeyEvent.KEYCODE_VOLUME_DOWN
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import android.app.RemoteAction
import android.app.PendingIntent
import android.graphics.drawable.Icon
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app/architecture"
    private val VOLUME_CHANNEL = "com.ryan.anymex/volume"
    private val VOLUME_EVENTS = "com.ryan.anymex/volume_events"
    private val PIP_CHANNEL = "com.ryan.anymex/pip"
    private var volumeKeysEnabled = false
    private var volumeEventsSink: EventChannel.EventSink? = null
    private var isPipActive = false
    private var pipMethodChannel: MethodChannel? = null

    private val ACTION_PIP_PLAY_PAUSE = "pip_play_pause"
    private val ACTION_PIP_SKIP = "pip_skip"
    private var isPlayingForPip = false

    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_PIP_PLAY_PAUSE -> pipMethodChannel?.invokeMethod("playPause", null)
                ACTION_PIP_SKIP -> pipMethodChannel?.invokeMethod("megaSeek", 85)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PIP_PLAY_PAUSE)
            addAction(ACTION_PIP_SKIP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(pipReceiver)
    }

    private fun buildPipParams(isPlaying: Boolean): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            isPlayingForPip = isPlaying
            val playPauseIconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
            val playPauseIcon = Icon.createWithResource(this, playPauseIconRes)
            val playPauseIntent = PendingIntent.getBroadcast(
                this, 1, Intent(ACTION_PIP_PLAY_PAUSE).setPackage(packageName), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val playPauseAction = RemoteAction(playPauseIcon, "Play/Pause", "Play/Pause", playPauseIntent)
            
            val skipIcon = Icon.createWithResource(this, android.R.drawable.ic_media_ff)
            val skipIntent = PendingIntent.getBroadcast(
                this, 2, Intent(ACTION_PIP_SKIP).setPackage(packageName), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val skipAction = RemoteAction(skipIcon, "Skip 85s", "Skip 85s", skipIntent)
            
            return PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .setActions(listOf(playPauseAction, skipAction))
                .build()
        }
        return null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentArchitecture" -> {
                    val architecture = getCurrentArchitecture()
                    result.success(architecture)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    volumeKeysEnabled = true
                    result.success(null)
                }
                "disable" -> {
                    volumeKeysEnabled = false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ryan.anymex/utils").setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            android.media.MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(path),
                                null
                            ) { _, _ -> }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SCAN_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null", null)
                    }
                }
                "setSensorLandscape" -> {
                    requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    result.success(true)
                }
                "resetOrientation" -> {
                    requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    result.success(true)
                }
                "setLandscapeLeft" -> {
                    // Flutter's landscapeLeft corresponds to standard LANDSCAPE on Android
                    requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    result.success(true)
                }
                "setLandscapeRight" -> {
                    // Flutter's landscapeRight corresponds to REVERSE_LANDSCAPE on Android
                    requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                    result.success(true)
                }
                "openOpenByDefaultSettings" -> {
                    try {
                        val packageUri = Uri.parse("package:$packageName")
                        val openByDefaultIntent = Intent(Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS).apply {
                            data = packageUri
                        }

                        if (openByDefaultIntent.resolveActivity(packageManager) != null) {
                            startActivity(openByDefaultIntent)
                        } else {
                            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = packageUri
                            }
                            startActivity(fallbackIntent)
                        }

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_DEFAULT_SETTINGS_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // PIP channel
        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = buildPipParams(isPlayingForPip)
                            if (params != null) {
                                isPipActive = enterPictureInPictureMode(params)
                                result.success(isPipActive)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("PIP_FAILED", e.message, null)
                        }
                    } else {
                        result.error("PIP_NOT_SUPPORTED", "PIP requires Android 8+", null)
                    }
                }
                "updatePipState" -> {
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val params = buildPipParams(isPlaying)
                        if (params != null) {
                            setPictureInPictureParams(params)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventsSink = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeEventsSink = null
                }
            }
        )
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Auto-enter PIP when user presses home button while video is playing
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                if (isPlayingForPip) {
                    val params = buildPipParams(isPlayingForPip)
                    if (params != null) {
                        isPipActive = enterPictureInPictureMode(params)
                    }
                }
            } catch (e: Exception) {
                // Ignore — not all devices support PIP
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isPipActive = isInPictureInPictureMode
        // Flutter will be notified via AppLifecycleState changes automatically
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeKeysEnabled && (event.keyCode == KEYCODE_VOLUME_UP || event.keyCode == KEYCODE_VOLUME_DOWN)) {
            if (event.action == ACTION_DOWN) {
                val direction = if (event.keyCode == KEYCODE_VOLUME_UP) "up" else "down"
                volumeEventsSink?.success(direction)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun getCurrentArchitecture(): String {
        return try {
            val primaryAbi = Build.SUPPORTED_ABIS?.firstOrNull()
            if (primaryAbi != null) {
                when {
                    primaryAbi.contains("arm64") || primaryAbi.contains("v8a") -> "arm64"
                    primaryAbi.contains("arm") || primaryAbi.contains("v7a") -> "arm32"
                    primaryAbi.contains("x86_64") -> "x86_64"
                    primaryAbi.contains("x86") -> "x86"
                    else -> primaryAbi
                }
            } else {
                getSystemProperty("ro.product.cpu.abi") ?: "unknown"
            }
        } catch (e: Exception) {
            e.printStackTrace()
            "unknown"
        }
    }

    private fun getSystemProperty(property: String): String? {
        return try {
            val process = Runtime.getRuntime().exec("getprop $property")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val result = reader.readLine()
            reader.close()
            process.waitFor()
            result
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}