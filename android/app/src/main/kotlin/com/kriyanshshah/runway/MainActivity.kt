package com.kriyanshshah.runway

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// local_auth's biometric prompt needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
  companion object {
    /** From the Quick Settings tile and the pinned "Log by voice" icon. */
    const val ACTION_VOICE_ADD = "com.kriyanshshah.runway.VOICE_ADD"
  }

  private var onDeviceModel: OnDeviceModel? = null
  private var quickLog: QuickLog? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val messenger = flutterEngine.dartExecutor.binaryMessenger
    onDeviceModel = OnDeviceModel(messenger)
    quickLog = QuickLog(applicationContext, messenger).also {
      it.handle(intent, appRunning = false)
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    quickLog?.handle(intent, appRunning = true)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    onDeviceModel?.dispose()
    onDeviceModel = null
    quickLog?.dispose()
    quickLog = null
    super.cleanUpFlutterEngine(flutterEngine)
  }
}
