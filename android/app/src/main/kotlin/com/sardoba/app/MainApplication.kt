package com.sardobabukhara.app

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Ensure MapKit API key is set before any map view is created.
        MapKitFactory.setApiKey(getString(R.string.yandex_mapkit_api_key))
    }
}
