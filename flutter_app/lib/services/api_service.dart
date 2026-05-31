import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

String activeBaseUrl = ApiService.baseUrl;

class ApiService {
  // For web browser testing, use localhost
  // For Android emulator, use 10.0.2.2
  // For physical device, use your machine's LAN IP
  static const String baseUrl = 'http://185.2.100.202:8000/api';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');
          if (userId != null) {
            options.headers['x-provider-id'] = userId;
          }
        } catch (e) {
          print('Error setting x-provider-id header in interceptor: $e');
        }
        return handler.next(options);
      },
    ));
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: activeBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Check for query parameter 'api'
      String? queryApiUrl = Uri.base.queryParameters['api'];
      
      if (queryApiUrl != null && queryApiUrl.isNotEmpty) {
        // Strip trailing slash if present
        if (queryApiUrl.endsWith('/')) {
          queryApiUrl = queryApiUrl.substring(0, queryApiUrl.length - 1);
        }
        // If the URL doesn't end with /api, append it
        if (!queryApiUrl.endsWith('/api')) {
          queryApiUrl = '$queryApiUrl/api';
        }
        activeBaseUrl = queryApiUrl;
        await prefs.setString('api_base_url', queryApiUrl);
        print('API Base URL updated from query parameter: $activeBaseUrl');
      } else {
        // 2. Check SharedPreferences
        String? savedApiUrl = prefs.getString('api_base_url');
        bool isStaleTunnel = false;
        if (savedApiUrl != null) {
          bool hostIsIpOrLocal = Uri.base.host == 'localhost' || 
                                 Uri.base.host == '127.0.0.1' || 
                                 RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(Uri.base.host);
          bool savedIsTunnel = savedApiUrl.contains('.lhr.life') || savedApiUrl.contains('.localhost.run');
          if (hostIsIpOrLocal && savedIsTunnel) {
            isStaleTunnel = true;
          }
        }

        if (savedApiUrl != null && savedApiUrl.isNotEmpty && !isStaleTunnel) {
          activeBaseUrl = savedApiUrl;
          print('API Base URL loaded from SharedPreferences: $activeBaseUrl');
        } else {
          // 3. Dynamic Host Inference for Web
          if (Uri.base.host.isNotEmpty) {
            String inferredScheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
            activeBaseUrl = '$inferredScheme://${Uri.base.host}:8000/api';
            print('API Base URL dynamically inferred from host: $activeBaseUrl');
          } else {
            print('API Base URL falling back to default: $activeBaseUrl');
          }
        }
      }
      
      // Update the singleton's dio instance baseUrl
      _instance._dio.options.baseUrl = activeBaseUrl;
    } catch (e) {
      print('Error initializing ApiService base URL: $e');
    }
  }

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
    String? scheduledTime,
  }) async {
    final response = await _dio.post('/request/select/', data: {
      'user_id': userId,
      'provider_id': providerId,
      'service_type': serviceType,
      'location': location,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
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

  // ==================== ADMIN & SYSTEM CONFIG ====================

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await _dio.get('/admin/stats/');
    return response.data;
  }

  Future<Map<String, dynamic>> toggleApifyGlobally() async {
    final response = await _dio.post('/admin/toggle-apify/');
    return response.data;
  }

  Future<Map<String, dynamic>> getSystemConfig({String? userId, String? role}) async {
    final response = await _dio.get('/system-config/', queryParameters: {
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateUserApifySetting({
    required String userId,
    required String role,
    required bool enabled,
  }) async {
    final response = await _dio.post('/users/update-apify/', data: {
      'user_id': userId,
      'role': role,
      'enabled': enabled,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getAdminUsers() async {
    final response = await _dio.get('/admin/users/');
    return response.data;
  }

  Future<Map<String, dynamic>> adminCreateUser(Map<String, dynamic> data) async {
    final response = await _dio.post('/admin/users/create/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> adminUpdateUser(Map<String, dynamic> data) async {
    final response = await _dio.post('/admin/users/update/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> adminDeleteUser(String id, String role) async {
    final response = await _dio.post('/admin/users/delete/', data: {
      'id': id,
      'role': role,
    });
    return response.data;
  }

  // ==================== PROVIDER PROFILE & GIG SYSTEM ====================

  Future<Map<String, dynamic>> getProviderProfile(String providerId) async {
    final response = await _dio.get('/provider/profile/$providerId/');
    return response.data;
  }

  Future<Map<String, dynamic>> updateProviderProfile(String providerId, Map<String, dynamic> data) async {
    final response = await _dio.post('/provider/profile/$providerId/', data: data);
    return response.data;
  }

  Future<List<dynamic>> getProviderGigs(String providerId) async {
    final response = await _dio.get('/provider/gigs/$providerId/');
    return response.data;
  }

  Future<Map<String, dynamic>> createProviderGig(String providerId, Map<String, dynamic> data) async {
    final response = await _dio.post('/provider/gigs/$providerId/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> editProviderGig(String providerId, String gigId, Map<String, dynamic> data) async {
    final response = await _dio.post('/provider/gigs/$providerId/edit/$gigId/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> deleteProviderGig(String providerId, String gigId) async {
    final response = await _dio.post('/provider/gigs/$providerId/delete/$gigId/');
    return response.data;
  }

  Future<Map<String, dynamic>> manageDiscounts(String providerId, Map<String, dynamic> data) async {
    final response = await _dio.post('/provider/discounts/$providerId/', data: data);
    return response.data;
  }

  Future<String> uploadImage(List<int> fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    final response = await _dio.post('/provider/upload-image/', data: formData);
    return response.data['url'];
  }

  Future<Map<String, dynamic>> addReview(Map<String, dynamic> data) async {
    final response = await _dio.post('/reviews/add/', data: data);
    return response.data;
  }
}
