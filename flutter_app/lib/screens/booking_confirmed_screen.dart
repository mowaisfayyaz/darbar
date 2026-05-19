import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';

class BookingConfirmedScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmedScreen({super.key, required this.bookingData});

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _showTraces = false;
  List<dynamic> _agentLogs = [];
  bool _loadingLogs = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAgentLogs() async {
    final bookingId = widget.bookingData['booking_id'];
    if (bookingId == null) return;

    setState(() => _loadingLogs = true);
    try {
      final api = ApiService();
      _agentLogs = await api.getAgentLogs(bookingId);
    } catch (e) {
      // Silent fail
    }
    if (mounted) setState(() => _loadingLogs = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    final data = widget.bookingData;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Booking Details', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Success animation
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Provider Matched!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data['human_booking_id'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // Provider Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF1565C0).withOpacity(0.12),
                        child: Text(
                          (data['provider_name'] ?? 'P')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['provider_name'] ?? 'Provider',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${data['provider_rating'] ?? 0.0}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (data['provider_reviews'] != null) ...[
                                  Text(
                                    ' (${data['provider_reviews']} reviews)',
                                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                            if (data['provider_area'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      data['provider_area'],
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (data['provider_phone'] != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 18, color: isDark ? Colors.grey[400] : Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['provider_phone'],
                            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.call, size: 16),
                            label: const Text('Call', style: TextStyle(fontSize: 13)),
                            onPressed: () async {
                              final phone = data['provider_phone'];
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Booking details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _detailRow(Icons.build_outlined, 'Service', data['service_type'] ?? 'N/A', isDark),
                  const Divider(height: 20),
                  _detailRow(Icons.location_on_outlined, 'Location', data['location'] ?? 'N/A', isDark),
                  if (data['human_booking_id'] != null) ...[
                    const Divider(height: 20),
                    _detailRow(Icons.confirmation_number_outlined, 'Booking ID', data['human_booking_id'], isDark),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // AI Reasoning panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1565C0).withOpacity(0.12) : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1565C0).withOpacity(isDark ? 0.3 : 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: isDark ? Colors.blue[300] : const Color(0xFF1565C0), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI Reasoning', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.blue[300] : const Color(0xFF1565C0),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data['message'] ?? 'Selected based on highest match score in your area.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Agent Trace Panel (collapsible)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Row(
                    children: [
                      Icon(Icons.timeline, color: isDark ? Colors.amber[300] : Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Agent Trace Log',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.amber[300] : Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Tap to view full agent pipeline',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey),
                  ),
                  onExpansionChanged: (expanded) {
                    if (expanded && _agentLogs.isEmpty && !_loadingLogs) {
                      _loadAgentLogs();
                    }
                    setState(() => _showTraces = expanded);
                  },
                  children: [
                    if (_loadingLogs)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_agentLogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No agent logs available for this booking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: _agentLogs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final log = entry.value;
                            final isLast = index == _agentLogs.length - 1;
                            return _buildTraceItem(log, isLast, isDark);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTraceItem(Map<String, dynamic> log, bool isLast, bool isDark) {
    final agentColors = {
      'Intent Agent': Colors.purple,
      'Discovery Agent': Colors.orange,
      'Ranking Agent': Colors.teal,
      'Decision Agent': Colors.blue,
      'Booking Agent': Colors.green,
      'Follow-Up Agent': Colors.indigo,
      'System': Colors.red,
    };

    final agentName = log['agent_name'] ?? 'Agent';
    final color = agentColors[agentName] ?? Colors.grey;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withOpacity(0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          agentName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    log['action_taken'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log['reasoning'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
