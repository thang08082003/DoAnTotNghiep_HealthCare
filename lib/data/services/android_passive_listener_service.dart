import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class AndroidPassiveListenerService {
  static const _channel = MethodChannel('com.example.healthcare/passive');

  static Future<bool> enable() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('enablePassiveListener');
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> disable() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('disablePassiveListener');
      return res == true;
    } on PlatformException {
      return false;
    }
  }
}
