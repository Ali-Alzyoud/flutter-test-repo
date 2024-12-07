import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cura_sdk/flutter_cura_sdk.dart';
import 'package:flutter_cura_sdk/flutter_cura_sdk_platform_interface.dart';
import 'package:flutter_cura_sdk/flutter_cura_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterCuraSdkPlatform
    with MockPlatformInterfaceMixin
    implements FlutterCuraSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterCuraSdkPlatform initialPlatform = FlutterCuraSdkPlatform.instance;

  test('$MethodChannelFlutterCuraSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterCuraSdk>());
  });

  test('getPlatformVersion', () async {
    FlutterCuraSdk flutterCuraSdkPlugin = FlutterCuraSdk();
    MockFlutterCuraSdkPlatform fakePlatform = MockFlutterCuraSdkPlatform();
    FlutterCuraSdkPlatform.instance = fakePlatform;

    expect(await flutterCuraSdkPlugin.getPlatformVersion(), '42');
  });
}
