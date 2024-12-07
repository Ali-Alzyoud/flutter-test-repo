import 'package:pigeon/pigeon.dart';

class ExampleRequest {
  String? text;
}

class ExampleResponse {
  String? reply;
}

@HostApi()
abstract class ExampleApi {
  ExampleResponse sendRequest(ExampleRequest request);
}
