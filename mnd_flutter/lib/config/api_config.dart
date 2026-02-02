class ApiConfig {
  // Using the special IP for Android Emulator to connect to the host machine.
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  
  // The original IP for a physical device on the same Wi-Fi:
  static const String baseUrl = 'http://192.168.0.114:3000/api';
  
  // For iOS simulator
  // static const String baseUrl = 'http://localhost:3000/api';
  
  static const Duration timeout = Duration(seconds: 30);
}
