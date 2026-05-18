import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  // Mock incoming requests
  final List<Map<String, dynamic>> _requests = [
    {
      'id': 'BK-2026-X1A',
      'service': 'AC Repair',
      'location': 'G-13, Islamabad',
      'time': 'As soon as possible',
      'customer': 'Ali Khan',
      'status': 'pending'
    }
  ];

  void _acceptRequest(int index) {
    setState(() {
      _requests[index]['status'] = 'accepted';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking Accepted! Customer has been notified.'), backgroundColor: Colors.green),
    );
  }

  void _declineRequest(int index) {
    setState(() {
      _requests.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking Declined.'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Provider Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _requests.isEmpty 
          ? Center(
              child: Text(
                'No active requests right now.',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final isAccepted = req['status'] == 'accepted';
                
                return Card(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              req['id'],
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAccepted 
                                    ? Colors.green.withOpacity(0.15) 
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isAccepted ? 'ACCEPTED' : 'PENDING',
                                style: TextStyle(
                                  color: isAccepted ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          req['service'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              req['location'],
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              req['time'],
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        if (!isAccepted)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => _declineRequest(index),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => _acceptRequest(index),
                                  child: const Text('Accept Request'),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.call),
                              label: const Text('Call Customer'),
                              onPressed: () {},
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
