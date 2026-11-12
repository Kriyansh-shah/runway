package com.kriyanshshah.runway

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Logging by voice from outside the app, for lib/app/quick_log.dart: the
 * Quick Settings tile ([LogTileService]) and a pinned "Log by voice"
 * home-screen icon both open [MainActivity] with [MainActivity.ACTION_VOICE_ADD].
 *
 * "take" answers whether the app was opened that way (once); "voiceAdd" is
 * sent when it happens while the app is already open. "addTile" and
 * "pinShortcut" ask the system to add either one, where it can.
 */
class QuickLog(private val context: Context, messenger: BinaryMessenger) {
  private val channel = MethodChannel(messenger, "runway/quick_log")
  private var pending = false

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "take" -> {
          result.success(pending)
          pending = false
        }
        "canAddTile" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
        "addTile" -> addTile(result)
        "canPinShortcut" -> result.success(canPin())
        "pinShortcut" -> result.success(pinShortcut())
        else -> result.notImplemented()
      }
    }
  }

  /** From the intent that opened or came back to the app. */
  fun handle(intent: Intent?, appRunning: Boolean) {
    if (intent?.action != MainActivity.ACTION_VOICE_ADD) return
    // Only once, even if the activity is recreated with the same intent.
    intent.action = Intent.ACTION_MAIN
    if (appRunning) channel.invokeMethod("voiceAdd", null) else pending = true
  }

  /** "added", "alreadyAdded", "notAdded" or "unsupported". */
  private fun addTile(result: MethodChannel.Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      result.success("unsupported")
      return
    }
    val bar = context.getSystemService(StatusBarManager::class.java)
    bar.requestAddTileService(
      ComponentName(context, LogTileService::class.java),
      "Log expense",
      Icon.createWithResource(context, R.drawable.ic_tile_mic),
      context.mainExecutor,
    ) { code ->
      result.success(
        when (code) {
          StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
          StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
          StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "notAdded"
          else -> "unsupported"
        },
      )
    }
  }

  private fun canPin(): Boolean =
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
      context.getSystemService(ShortcutManager::class.java).isRequestPinShortcutSupported

  /** True if the launcher was asked; it shows its own confirmation. */
  private fun pinShortcut(): Boolean {
    if (!canPin() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
    val shortcut = ShortcutInfo.Builder(context, "pinned_voice_add")
      .setShortLabel("Log by voice")
      .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
      .setIntent(
        Intent(context, MainActivity::class.java).setAction(MainActivity.ACTION_VOICE_ADD),
      )
      .build()
    return context.getSystemService(ShortcutManager::class.java)
      .requestPinShortcut(shortcut, null)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }
}
