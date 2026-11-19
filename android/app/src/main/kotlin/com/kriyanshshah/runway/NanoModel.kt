package com.kriyanshshah.runway

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.SystemInstruction
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The ML Kit side of [OnDeviceModel]. Kept in its own class so phones older
 * than Android 14, which can't have Gemini Nano, never load ML Kit at all.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class NanoModel {
  private val downloads = CoroutineScope(SupervisorJob() + Dispatchers.Default)
  private var downloading = false
  private val model: GenerativeModel by lazy { Generation.getClient() }

  /**
   * "available", or why not: "notReady" (downloading; started here if it
   * hadn't been), "notEligible" (this phone has no Gemini Nano) or
   * "unsupported" (AICore missing or failing, an unlocked bootloader…).
   */
  suspend fun status(): String {
    val status = try {
      model.checkStatus()
    } catch (e: Exception) {
      Log.i("Runway", "Gemini Nano status unavailable: ${e.message}")
      return "unsupported"
    }
    return when (status) {
      FeatureStatus.AVAILABLE -> "available"
      FeatureStatus.DOWNLOADING -> "notReady"
      FeatureStatus.DOWNLOADABLE -> {
        startDownload()
        "notReady"
      }
      else -> "notEligible"
    }
  }

  /** In the background, once; the rules answer until it's ready. */
  private fun startDownload() {
    if (downloading) return
    downloading = true
    downloads.launch {
      try {
        model.download().collect { status ->
          if (status is DownloadStatus.DownloadFailed) {
            Log.i("Runway", "Gemini Nano download failed")
            downloading = false
          } else if (status == DownloadStatus.DownloadCompleted) {
            downloading = false
          }
        }
      } catch (e: Exception) {
        Log.i("Runway", "Gemini Nano download failed: ${e.message}")
        downloading = false
      }
    }
  }

  /**
   * A short reply to [prompt], or null if the model isn't ready. Throws when
   * generation fails (quota, the app in the background, …).
   */
  suspend fun respond(instructions: String, prompt: String, temperature: Float): String? {
    if (status() != "available") return null
    val request = if (model.isSystemPromptAvailable()) {
      generateContentRequest(SystemInstruction(instructions), TextPart(prompt)) {
        this.temperature = temperature
        maxOutputTokens = 250
      }
    } else {
      generateContentRequest(TextPart("$instructions\n\n$prompt")) {
        this.temperature = temperature
        maxOutputTokens = 250
      }
    }
    val text = model.generateContent(request).candidates.firstOrNull()?.text
    return text?.trim()?.ifEmpty { null }
  }

  fun close() {
    downloads.cancel()
    model.close()
  }
}
