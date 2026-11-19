package com.kriyanshshah.runway

import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Gemini Nano for the coach, the weekly recap and the Quick Add mic, through
 * ML Kit's Prompt API. Everything runs on the phone. The Dart side
 * (lib/app/on_device_coach.dart) falls back to the rule-based coach whenever
 * this says it isn't available or a reply fails.
 *
 * Same channel and methods as ios/Runner/CoachModel.swift: "status" and
 * "respond". Gemini Nano only ships on Android 14 and later, so older phones
 * never load the ML Kit classes (see [NanoModel]).
 */
class OnDeviceModel(messenger: BinaryMessenger) {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val channel = MethodChannel(messenger, "runway/coach")
  private val nano: NanoModel? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) NanoModel() else null

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "status" -> {
          val nano = nano
          if (nano == null) {
            result.success("unsupported")
            return@setMethodCallHandler
          }
          scope.launch { result.success(nano.status()) }
        }
        "respond" -> {
          val nano = nano
          val instructions = call.argument<String>("instructions")
          val prompt = call.argument<String>("prompt")
          if (instructions == null || prompt == null) {
            result.error("bad_arguments", null, null)
            return@setMethodCallHandler
          }
          if (nano == null) {
            result.success(null)
            return@setMethodCallHandler
          }
          val temperature = call.argument<Double>("temperature")?.toFloat() ?: 0.4f
          scope.launch {
            try {
              result.success(nano.respond(instructions, prompt, temperature))
            } catch (e: Exception) {
              Log.w("Runway", "Gemini Nano failed", e)
              result.error("generation_failed", e.message, null)
            }
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    nano?.close()
    scope.cancel()
  }
}
