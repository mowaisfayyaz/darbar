import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'booking_confirmed_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const ProcessingScreen({super.key, required this.requestData});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int _currentStep = 0;
  final List<String> _agentSteps = [
    "Understanding your request...",
    "Finding providers near you...",
    "Ranking top candidates...",
    "Contacting the best provider...",
    "Securing your booking..."
  ];

  @override
  void initState() {
    super.initState();
    _simulateAgentProcess();
  }

  void _simulateAgentProcess() async {
    for (int i = 0; i < _agentSteps.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _currentStep = i;
        });
      }
    }
    
    // After processing, navigate to confirmed screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmedScreen(
            bookingData: widget.requestData,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 4),
            const SizedBox(height: 40),
            Text(
              'Agent Pipeline Active',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _agentSteps[_currentStep],
                key: ValueKey<int>(_currentStep),
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
