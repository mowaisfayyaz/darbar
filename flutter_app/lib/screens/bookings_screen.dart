import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'booking_confirmed_screen.dart';
import 'app_drawer.dart';

class BookingsScreen extends StatefulWidget {
  final String userId;
  const BookingsScreen({super.key, required this.userId});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    // Auto-refresh every 15 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Silent refresh without showing loading indicator
  Future<void> _silentRefresh() async {
    try {
      final bookings = await _api.getUserBookings(widget.userId);
      if (mounted) {
        setState(() {
          _bookings = bookings;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBookings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final bookings = await _api.getUserBookings(widget.userId);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load bookings. Pull down to retry.';
          _isLoading = false;
        });
      }
    }
  }

  void _openBookingDetails(dynamic booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmedScreen(
          bookingData: {
            'booking_id': booking['id'],
            'human_booking_id': booking['booking_id'],
            'provider_name': booking['provider']?['business_name'] ?? 'Provider',
            'provider_rating': booking['provider']?['rating'] ?? 0,
            'provider_phone': booking['provider']?['phone'],
            'provider_area': booking['provider']?['area'],
            'provider_reviews': booking['provider']?['review_count'],
            'service_type': booking['service_type'],
            'location': booking['location'],
            'message': 'View agent traces below for detailed reasoning.',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      drawer: const AppDrawer(isProviderTheme: false),
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBookings),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBookings,
        color: const Color(0xFF1565C0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState(isDark)
                : _bookings.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) => _buildBookingCard(_bookings[index], isDark),
                      ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(onPressed: _fetchBookings, child: const Text('Try Again')),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(isDark ? 0.12 : 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.calendar_today_outlined, size: 56, color: Color(0xFF1565C0)),
        ),
        const SizedBox(height: 24),
        Text(
          'No bookings yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          'Your service bookings will appear here once you make a request through the AI agent.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildBookingCard(dynamic booking, bool isDark) {
    final status = booking['status'] ?? 'pending';
    
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return GestureDetector(
      onTap: () => _openBookingDetails(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    booking['booking_id'] ?? 'BK-XXXX',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Service type
            Text(
              booking['service_type'] ?? 'Service',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // Location
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  booking['location'] ?? 'Unknown',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                ),
              ],
            ),

            // Provider info
            if (booking['provider'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: isDark ? Colors.grey[400] : Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      booking['provider']['business_name'] ?? '',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    '${booking['provider']['rating'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ],

            // Tap hint
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (status == 'completed' && booking['review'] == null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _showReviewDialog(booking),
                    icon: const Icon(Icons.rate_review, size: 16),
                    label: const Text('Leave Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                else if (status == 'completed' && booking['review'] != null)
                  const Row(
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Reviewed', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  )
                else
                  const SizedBox(),
                Text(
                  'Tap for details & agent traces →',
                  style: TextStyle(fontSize: 11, color: const Color(0xFF1565C0).withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(dynamic booking) {
    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Leave a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How was your service with ${booking['provider']?['business_name'] ?? 'the provider'}?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        icon: Icon(
                          starIndex <= rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            rating = starIndex;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comments (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      final result = await _api.addReview({
                        'booking_id': booking['id'],
                        'rating': rating,
                        'comment': commentController.text.trim(),
                      });
                      setState(() {
                        booking['review'] = result;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review submitted successfully! Thank you.'), backgroundColor: Colors.green),
                      );
                      _fetchBookings();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit review: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
