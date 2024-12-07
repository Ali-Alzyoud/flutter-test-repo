import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_cura_sdk_method_channel.dart';

abstract class FlutterCuraSdkPlatform extends PlatformInterface {
  /// Constructs a FlutterCuraSdkPlatform.
  FlutterCuraSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterCuraSdkPlatform _instance = MethodChannelFlutterCuraSdk();

  /// The default instance of [FlutterCuraSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterCuraSdk].
  static FlutterCuraSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterCuraSdkPlatform] when
  /// they register themselves.
  static set instance(FlutterCuraSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
