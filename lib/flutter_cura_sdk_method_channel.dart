import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_cura_sdk_platform_interface.dart';

/// An implementation of [FlutterCuraSdkPlatform] that uses method channels.
class MethodChannelFlutterCuraSdk extends FlutterCuraSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_cura_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
