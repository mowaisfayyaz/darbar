import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'booking_confirmed_screen.dart';

class BookingsScreen extends StatefulWidget {
  final String userId;
  const BookingsScreen({super.key, required this.userId});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Dio();
      final response = await dio.get('http://127.0.0.1:8000/api/bookings/user/${widget.userId}/');
      setState(() {
        _bookings = response.data;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['error'] ?? 'Failed to load bookings. Please swipe down to refresh.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBookings,
        color: const Color(0xFF1565C0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchBookings,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                : _bookings.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 100),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.book_online_outlined, size: 64, color: Color(0xFF1565C0)),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No bookings yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Go to the Chat Agent tab and request a service to create one!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          final status = booking['status'] ?? 'pending';
                          
                          Color statusColor;
                          switch (status) {
                            case 'confirmed':
                              statusColor = Colors.green;
                              break;
                            case 'completed':
                              statusColor = Colors.blue;
                              break;
                            case 'cancelled':
                              statusColor = Colors.red;
                              break;
                            default:
                              statusColor = Colors.orange;
                          }

                          return Card(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingConfirmedScreen(
                                      bookingData: {
                                        'booking_id': booking['id'],
                                        'provider_name': booking['provider'] != null ? booking['provider']['business_name'] : 'Searching...',
                                        'provider_rating': booking['provider'] != null ? booking['provider']['rating'] : 0.0,
                                        'message': 'Booking ID: ${booking['booking_id']}\nService: ${booking['service_type']}\nLocation: ${booking['location']}\nStatus: ${booking['status']}',
                                      },
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          booking['booking_id'] ?? 'BK-XXXXXX',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      booking['service_type'] ?? 'General Service',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          booking['location'] ?? 'Unknown location',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Requested: ${booking['created_at'].toString().substring(0, 10)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        const Text(
                                          'Details ➔',
                                          style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
