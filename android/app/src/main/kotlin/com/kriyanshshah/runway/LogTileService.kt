package com.kriyanshshah.runway

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * "Log expense" in the swipe-down Quick Settings panel: opens Quick Add
 * already listening, the Android stand-in for "Hey Siri, log in Runway".
 * The app picks the request up in [MainActivity].
 */
class LogTileService : TileService() {
  override fun onStartListening() {
    qsTile?.apply {
      state = Tile.STATE_INACTIVE
      updateTile()
    }
  }

  @SuppressLint("StartActivityAndCollapseDeprecated")
  override fun onClick() {
    val open = QuickLog.voiceAddIntent(this)
      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    // On a locked phone, unlock first: the app lock and the budget are
    // behind it.
    unlockAndRun {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        startActivityAndCollapse(
          PendingIntent.getActivity(
            this, 0, open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
          ),
        )
      } else {
        @Suppress("DEPRECATION")
        startActivityAndCollapse(open)
      }
    }
  }
}
