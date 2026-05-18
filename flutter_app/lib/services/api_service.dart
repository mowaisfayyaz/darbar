import 'package:dio/dio.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access localhost, or actual IP for physical device
  static const String baseUrl = 'http://10.0.2.2:8000/api'; 
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> submitRequest(String text, String userId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/request/',
        data: {
          'text': text,
          'user_id': userId,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to submit request: $e');
    }
  }
  
  // Future methods for getting bookings and logs
}
