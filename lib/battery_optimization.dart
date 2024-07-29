import 'package:flutter/services.dart';

class BatteryOptimization {
  static const MethodChannel _channel =
      const MethodChannel('battery_optimization');

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (e) {
      print("Failed to request ignore battery optimizations: '${e.message}'.");
    }
  }
}
