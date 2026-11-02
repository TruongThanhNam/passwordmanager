package io.github.truongthanhnam.pakmanager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    PlatformApi.setUp(flutterEngine.dartExecutor.binaryMessenger, PlatformApiImpl(this))
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    PlatformApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
    super.cleanUpFlutterEngine(flutterEngine)
  }
}
