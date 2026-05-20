import 'package:dio/dio.dart';

class ApiService {
  // For web browser testing, use localhost
  // For Android emulator, use 10.0.2.2
  // For physical device, use your machine's LAN IP
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // ==================== AUTH ====================

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required String role,
  }) async {
    final response = await _dio.post('/auth/login/', data: {
      'identifier': identifier,
      'password': password,
      'role': role,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    String? category,
    String? city,
    String? area,
  }) async {
    final response = await _dio.post('/auth/register/', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
      if (category != null) 'category': category,
      if (city != null) 'city': city,
      if (area != null) 'area': area,
    });
    return response.data;
  }

  // ==================== AGENT ORCHESTRATOR ====================

  Future<Map<String, dynamic>> submitRequest({
    required String userId,
    required String text,
  }) async {
    final response = await _dio.post('/request/', data: {
      'user_id': userId,
      'text': text,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> selectProvider({
    required String userId,
    required String providerId,
    required String serviceType,
    required String location,
  }) async {
    final response = await _dio.post('/request/select/', data: {
      'user_id': userId,
      'provider_id': providerId,
      'service_type': serviceType,
      'location': location,
    });
    return response.data;
  }


  // ==================== BOOKINGS ====================

  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    final response = await _dio.get('/bookings/$bookingId/');
    return response.data;
  }

  Future<List<dynamic>> getUserBookings(String userId) async {
    final response = await _dio.get('/bookings/user/$userId/');
    return response.data;
  }

  Future<Map<String, dynamic>> confirmBooking({
    required String bookingId,
    required String status,
  }) async {
    final response = await _dio.post('/confirm/', data: {
      'booking_id': bookingId,
      'status': status,
    });
    return response.data;
  }

  // ==================== AGENT LOGS ====================

  Future<List<dynamic>> getAgentLogs(String bookingId) async {
    final response = await _dio.get('/logs/$bookingId/');
    return response.data;
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<dynamic>> getNotifications(String userId) async {
    final response = await _dio.get('/notifications/$userId/');
    return response.data;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.post('/notifications/read/$notificationId/');
  }

  // ==================== PROVIDERS ====================

  Future<List<dynamic>> listProviders() async {
    final response = await _dio.get('/providers/');
    return response.data;
  }

  // ==================== PROVIDER DASHBOARD ====================

  Future<List<dynamic>> getProviderBookings(String providerId) async {
    final response = await _dio.get('/provider/bookings/$providerId/');
    return response.data;
  }

  Future<Map<String, dynamic>> providerRespond({
    required String bookingId,
    required String providerId,
    required String action,
  }) async {
    final response = await _dio.post('/provider/respond/', data: {
      'booking_id': bookingId,
      'provider_id': providerId,
      'action': action,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    final response = await _dio.get('/provider/stats/$providerId/');
    return response.data;
  }

  Future<Map<String, dynamic>> toggleAvailability(String providerId) async {
    final response = await _dio.post('/provider/toggle-availability/$providerId/');
    return response.data;
  }

  // ==================== GOOGLE OAUTH ====================

  Future<String?> getGoogleAuthUrl({String? userId, String? role}) async {
    final response = await _dio.get('/auth/google/url/', queryParameters: {
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
    });
    return response.data['url'];
  }

  Future<Map<String, dynamic>> getGoogleAuthStatus({String? userId, String? role}) async {
    final response = await _dio.get('/auth/google/status/', queryParameters: {
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
    });
    return response.data;
  }

  Future<void> disconnectGoogle({String? userId, String? role}) async {
    await _dio.post('/auth/google/disconnect/', data: {
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
    });
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? accessToken,
    required String role,
  }) async {
    final response = await _dio.post('/auth/google-login/', data: {
      if (idToken != null) 'id_token': idToken,
      if (accessToken != null) 'access_token': accessToken,
      'role': role,
    });
    return response.data;
  }

  Future<String?> getGoogleClientId() async {
    final response = await _dio.get('/auth/google/config/');
    return response.data['client_id'];
  }
}
