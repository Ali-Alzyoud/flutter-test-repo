import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class StorageObserver {
  static final StorageObserver _instance = StorageObserver._internal();
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  factory StorageObserver() {
    return _instance;
  }

  StorageObserver._internal();

  Stream<String> get onStorageChanged => _controller.stream;

  Future<void> updateValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _controller.add(key); // Notify listeners about the change
  }

  Future<void> removeValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    _controller.add(key); // Notify listeners about the change
  }
}
