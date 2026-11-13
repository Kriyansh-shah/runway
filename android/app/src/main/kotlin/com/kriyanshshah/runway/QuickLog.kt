package com.kriyanshshah.runway

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import java.security.SecureRandom
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Logging by voice from outside the app, for lib/app/quick_log.dart: the
 * Quick Settings tile ([LogTileService]), the long-press "Log by voice"
 * shortcut and a pinned "Log by voice" home-screen icon all open
 * [MainActivity] with [voiceAddIntent].
 *
 * MainActivity is exported (the launcher needs it), so any app could send it
 * that action. Each of Runway's own intents carries a random secret made on
 * this phone and kept in Runway's private storage; a request without it
 * just opens the app, without the mic.
 *
 * "take" answers whether the app was opened that way (once); "voiceAdd" is
 * sent when it happens while the app is already open. "addTile" and
 * "pinShortcut" ask the system to add either one, where it can.
 */
class QuickLog(private val context: Context, messenger: BinaryMessenger) {
  companion object {
    private const val EXTRA_SECRET = "com.kriyanshshah.runway.QUICK_LOG_SECRET"

    /** This phone's secret, made once. */
    private fun secret(context: Context): String {
      val prefs = context.getSharedPreferences("runway_quick_log", Context.MODE_PRIVATE)
      prefs.getString("secret", null)?.let { return it }
      val bytes = ByteArray(16).also { SecureRandom().nextBytes(it) }
      val made = bytes.joinToString("") { "%02x".format(it) }
      prefs.edit().putString("secret", made).apply()
      return made
    }

    /** Opens Quick Add listening: for the tile and the shortcuts. */
    fun voiceAddIntent(context: Context): Intent =
      Intent(context, MainActivity::class.java)
        .setAction(MainActivity.ACTION_VOICE_ADD)
        .putExtra(EXTRA_SECRET, secret(context))

    fun isOurs(context: Context, intent: Intent): Boolean {
      val sent = intent.getStringExtra(EXTRA_SECRET) ?: return false
      return java.security.MessageDigest.isEqual(
        sent.toByteArray(),
        secret(context).toByteArray(),
      )
    }
  }

  private val channel = MethodChannel(messenger, "runway/quick_log")
  private var pending = false

  init {
    publishLongPressShortcut()
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
    if (!isOurs(context, intent)) return
    if (appRunning) channel.invokeMethod("voiceAdd", null) else pending = true
  }

  /** Long-press the app icon → "Log by voice" (Android 7.1+). */
  private fun publishLongPressShortcut() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
    val shortcut = ShortcutInfo.Builder(context, "voice_add")
      .setShortLabel("Log by voice")
      .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
      .setIntent(voiceAddIntent(context))
      .build()
    try {
      context.getSystemService(ShortcutManager::class.java)
        .setDynamicShortcuts(listOf(shortcut))
    } catch (e: Exception) {
      // Rate-limited or not supported by the launcher: no shortcut.
    }
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
      .setIntent(voiceAddIntent(context))
      .build()
    return context.getSystemService(ShortcutManager::class.java)
      .requestPinShortcut(shortcut, null)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }
}
