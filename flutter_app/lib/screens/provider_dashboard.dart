import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'app_drawer.dart';

class ProviderDashboard extends StatefulWidget {
  final String providerId;
  final String providerName;
  const ProviderDashboard({super.key, required this.providerId, required this.providerName});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  final ApiService _api = ApiService();
  List<dynamic> _bookings = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final bookings = await _api.getProviderBookings(widget.providerId);
      Map<String, dynamic>? stats;
      try {
        stats = await _api.getProviderStats(widget.providerId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _stats = stats;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final bookings = await _api.getProviderBookings(widget.providerId);
      Map<String, dynamic>? stats;
      try {
        stats = await _api.getProviderStats(widget.providerId);
      } catch (_) {}
      
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _stats = stats;
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

  Future<void> _respondToBooking(String bookingId, String action) async {
    try {
      await _api.providerRespond(
        bookingId: bookingId,
        providerId: widget.providerId,
        action: action,
      );
      if (mounted) {
        String msg = 'Booking declined.';
        Color bgColor = Colors.red;
        if (action == 'accept') {
          msg = '✅ Booking accepted! Customer notified.';
          bgColor = Colors.green;
        } else if (action == 'complete') {
          msg = '🎉 Booking marked as completed!';
          bgColor = Colors.blue;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: bgColor,
          ),
        );
      }
      _loadData(); // Refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to respond: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      final result = await _api.toggleAvailability(widget.providerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Status updated'),
            backgroundColor: result['is_available'] == true ? Colors.green : Colors.orange,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      drawer: const AppDrawer(isProviderTheme: true),
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Provider Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: Colors.green,
            child: _isLoading
                ? const DashboardSkeletonLoader()
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 100),
                          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Stats header
                          _buildStatsCard(isDark),
                      const SizedBox(height: 20),
                      
                      // Welcome banner if new provider (0 bookings and 0 total jobs)
                      if (_bookings.isEmpty && (_stats?['total_bookings'] ?? 0) == 0) ...[
                        _buildWelcomeBanner(isDark),
                        const SizedBox(height: 20),
                      ],
                      
                      // Section header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Incoming Requests',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            '${_bookings.where((b) => b['status'] == 'pending').length} pending',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_bookings.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.inbox_outlined, size: 56, color: Colors.green),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No active requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'New booking requests will appear here.',
                                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._bookings.map((booking) => _buildBookingCard(booking, isDark)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2E1E) : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.green, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Darbar!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete your profile and toggle Online to start receiving client booking requests.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    final stats = _stats ?? {};
    final isOnline = stats['is_available'] == true;
    final ratingVal = double.tryParse(stats['rating']?.toString() ?? '0') ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.green.shade900, Colors.green.shade800]
              : [Colors.green.shade600, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats['provider_name'] ?? widget.providerName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats['category'] ?? 'Service Provider',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _toggleAvailability,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: isOnline ? Colors.greenAccent : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statItem('Rating', '${stats['rating'] ?? 0.0} ⭐'),
              _statItem('Reviews', '${stats['review_count'] ?? 0}'),
              _statItem('Total Jobs', '${stats['total_bookings'] ?? 0}'),
              _statItem('Pending', '${stats['pending_bookings'] ?? 0}'),
            ],
          ),
          if (ratingVal == 0.0) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white30, height: 1),
            const SizedBox(height: 8),
            const Text(
              'Rating will appear after your first completed job',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBookingCard(dynamic booking, bool isDark) {
    final status = booking['status'] ?? 'pending';
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';

    Color statusColor;
    switch (status) {
      case 'confirmed': statusColor = Colors.green; break;
      case 'completed': statusColor = Colors.blue; break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPending ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5) : null,
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking['booking_id'] ?? 'BK-XXXXX',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Service info
          Text(
            booking['service_type'] ?? 'Service',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: isDark ? Colors.grey[400] : Colors.grey, size: 18),
              const SizedBox(width: 6),
              Text(
                booking['location'] ?? 'Unknown',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
          if (booking['scheduled_time'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: isDark ? Colors.grey[400] : Colors.grey, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatScheduledTime(booking['scheduled_time']),
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, color: isDark ? Colors.grey[400] : Colors.grey, size: 18),
              const SizedBox(width: 6),
              Text(
                'Customer: ${booking['user'] is Map ? (booking['user']['name'] ?? 'N/A') : (booking['user'] ?? 'N/A')}',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),

          // Action buttons
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _respondToBooking(booking['id'], 'decline'),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _respondToBooking(booking['id'], 'accept'),
                    child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (isConfirmed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark as Completed', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _respondToBooking(booking['id'], 'complete'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatScheduledTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Flexible / ASAP';
    try {
      final dateTime = DateTime.parse(timeStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dateTime.month - 1];
      final day = dateTime.day;
      final year = dateTime.year;
      final hourVal = dateTime.hour;
      final minuteVal = dateTime.minute.toString().padLeft(2, '0');
      final period = hourVal >= 12 ? 'PM' : 'AM';
      final hour = hourVal == 0 ? 12 : (hourVal > 12 ? hourVal - 12 : hourVal);
      return '$month $day, $year at $hour:$minuteVal $period';
    } catch (e) {
      return timeStr;
    }
  }
}

class DashboardSkeletonLoader extends StatefulWidget {
  const DashboardSkeletonLoader({super.key});

  @override
  State<DashboardSkeletonLoader> createState() => _DashboardSkeletonLoaderState();
}

class _DashboardSkeletonLoaderState extends State<DashboardSkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.4 + (_controller.value * 0.4);
        return Opacity(
          opacity: opacity,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Stats Card skeleton
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 120, height: 16, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                        Container(width: 80, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(3, (index) => Column(
                        children: [
                          Container(width: 40, height: 24, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 8),
                          Container(width: 60, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                        ],
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Section Header skeleton
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 150, height: 18, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                  Container(width: 60, height: 14, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                ],
              ),
              const SizedBox(height: 16),
              // Incoming request list skeletons
              ...List.generate(2, (index) => Container(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 90, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                        Container(width: 60, height: 18, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(8))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(width: 160, height: 16, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(width: 14, height: 14, decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Container(width: 110, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}
