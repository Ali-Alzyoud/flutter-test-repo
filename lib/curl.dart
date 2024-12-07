import 'dart:convert';

void printCurlCommand(String url, String httpMethod,
    Map<String, String> headers, Map<String, dynamic> body) {
  // Start building the curl command
  String curlCommand = 'curl -X $httpMethod "$url"';

  // Add headers to the curl command
  headers.forEach((key, value) {
    curlCommand += ' -H "$key: $value"';
  });

  // Add body to the curl command if it is a POST request and there is data to send
  if (httpMethod == "POST" && body.isNotEmpty) {
    final bodyString = jsonEncode(body);
    curlCommand += " -d '$bodyString'";
  }

  // Print the full curl command
  print(curlCommand);
}
