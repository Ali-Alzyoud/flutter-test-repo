import 'dart:convert';
import 'package:flutter_cura_sdk/cura_view.dart';
import 'package:flutter_cura_sdk/curl.dart';
import 'package:flutter_cura_sdk/storage_observer.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

final storageObserver = StorageObserver();
Future<void> saveAuthData(Map<String, dynamic> user) async {

  final userSessionResponse = user['UserSessionResponse'];
  if (userSessionResponse == null) {
    return;
  }

  await Future.wait([
    storageObserver.updateValue(
        'refreshToken', userSessionResponse['RefreshToken']),
    storageObserver.updateValue('userId', userSessionResponse['UserId']),
    storageObserver.updateValue(
        'userInfo', jsonEncode(userSessionResponse['Meta'])),
    storageObserver.updateValue('jwtToken', userSessionResponse['BearerToken']),
  ]);

}

Future<void> removeAuthData() async {
  Future.wait([
    storageObserver.removeValue('jwtToken'),
   storageObserver.removeValue('refreshToken'),
   storageObserver.removeValue('userId'),
   storageObserver.removeValue('userInfo')
  ]);
}

class Endpoints {
  static const String authProd =
      "https://api.cura.healthcare/RegisterOrLoginCuraWebSdkHostAppCustomer";
  static const String devAuth =
      "https://api-dev-website-1.cura.healthcare/RegisterOrLoginCuraWebSdkHostAppCustomer";
}

class CuraAuth {
  static Future<Object> loginByMobileNumber(
      Map<String, dynamic> userProfile) async {
    final urlString =
        CuraSDKView().isProd ? Endpoints.authProd : Endpoints.devAuth;
    final url = CuraSDKView().isProd
        ? Uri.parse(Endpoints.authProd)
        : Uri.parse(Endpoints.devAuth);
    print("url $url");
    final deviceToken = await CuraSDKView().getDeviceToken();
    final sNSEndPointArn = await CuraSDKView().getSNSEndPointArn();
    final voIPDeviceToken = await CuraSDKView().getVoIPDeviceToken();
    final sNSVoIPEndPointArn = await CuraSDKView().getSNSVoIPEndPointArn();
    final packageInfo = await PackageInfo.fromPlatform();
    String bundleIdentifier = packageInfo.packageName;

    final headers = {
      'Content-Type': 'application/json',
      'Accept-Language': CuraSDKView().locale,
      'X-ApiKey': CuraSDKView().apiKey,
      'X-ClientOrganizationId': CuraSDKView().organizationId,
      'X-ClientId': "com.ubieva.cura" ?? bundleIdentifier,
      'X-ClientVersion': '1.8.1',
      'X-WebSdkVersion': '1.8.1',
    };

    final parameters = {
      'OrganizationId': CuraSDKView().organizationId ?? '',
      'IntegratorUserId': userProfile['IntegratorUserId'] ?? '',
      'MobileNumber': userProfile['MobileNumber'] ?? '',
      'DeviceToken': userProfile['DeviceToken'] ?? deviceToken ?? '',
      'SNSEndPointArn': sNSEndPointArn ?? '',
      'VoIPDeviceToken': voIPDeviceToken ?? '',
      'SNSVoIPEndPointArn': sNSVoIPEndPointArn ?? '',
      'UserName': userProfile['UserName'] ?? '',
      'Email': userProfile['Email'] ?? '',
      'DisplayName': userProfile['DisplayName'] ?? '',
      'Created': userProfile['Created'] ?? '',
      'Modified': userProfile['Modified'] ?? '',
      'Password': userProfile['Password'] ?? '',
      'Gender': userProfile['Gender'] ?? '',
      'LocationCountryId': userProfile['LocationCountryId'] ?? '',
      'Birthdate': userProfile['Birthdate'] ?? '',
      'FirstName': userProfile['FirstName'] ?? '',
      'LastName': userProfile['LastName'] ?? '',
      'UserConsentCollected': 'true',
      'PinCode': '',
      'PinCodeRequestId': '',
      'patients': userProfile['patients']
    };

    printCurlCommand(urlString, "POST", headers, parameters);

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(parameters),
      );

      if (response.statusCode == 200) {
        // print('Request successful: ${response.body}');
        saveAuthData(jsonDecode(response.body));
        return response.body;
      } else {
        print('Request failed with body: ${response.body}');
        print('Request failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Failed to make request: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await removeAuthData();
  }
}
