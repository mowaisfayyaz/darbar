import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'booking_confirmed_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const ProcessingScreen({super.key, required this.bookingData});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  
  final List<_AgentStep> _agentSteps = [
    _AgentStep('Intent Agent', 'Understanding your request...', Icons.psychology),
    _AgentStep('Discovery Agent', 'Finding providers near you...', Icons.search),
    _AgentStep('Ranking Agent', 'Scoring and ranking candidates...', Icons.leaderboard),
    _AgentStep('Decision Agent', 'Selecting the best provider...', Icons.check_circle_outline),
    _AgentStep('Booking Agent', 'Securing your booking...', Icons.bookmark_add),
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _simulateAgentProcess();
  }

  void _simulateAgentProcess() async {
    for (int i = 0; i < _agentSteps.length; i++) {
      await Future.delayed(Duration(milliseconds: i == 0 ? 800 : 1200));
      if (mounted) {
        setState(() => _currentStep = i + 1);
      }
    }
    
    // Brief pause to show all completed
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmedScreen(bookingData: widget.bookingData),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A0A1A), const Color(0xFF0D1B2A), const Color(0xFF1B2838)]
                : [const Color(0xFF0D47A1), const Color(0xFF1565C0), const Color(0xFF1976D2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
            children: [
              const SizedBox(height: 40),

              // Header
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Agent Pipeline Active',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Our AI agents are working on your request',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
              ),

              const SizedBox(height: 48),

              // Agent steps
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  itemCount: _agentSteps.length,
                  itemBuilder: (context, index) {
                    final step = _agentSteps[index];
                    final isCompleted = index < _currentStep;
                    final isActive = index == _currentStep - 1 || (index == 0 && _currentStep == 0);
                    final isPending = index >= _currentStep;

                    return _buildStepItem(step, isCompleted, isActive && !isCompleted, isPending, index, isDark);
                  },
                ),
              ),

              // Service info footer
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white.withOpacity(0.6), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Booking ${widget.bookingData['service_type'] ?? 'Service'} in ${widget.bookingData['location'] ?? 'your area'}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildStepItem(_AgentStep step, bool isCompleted, bool isActive, bool isPending, int index, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withOpacity(0.15)
            : isActive
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.4)
              : isActive
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.08),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.2)
                  : isActive
                      ? const Color(0xFF42A5F5).withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.green, size: 22)
                : isActive
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      )
                    : Icon(step.icon, color: Colors.white.withOpacity(0.3), size: 20),
          ),
          const SizedBox(width: 14),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.agentName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isCompleted || isActive ? Colors.white : Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCompleted ? 'Completed ✓' : step.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted
                        ? Colors.green[300]
                        : isActive
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentStep {
  final String agentName;
  final String description;
  final IconData icon;

  _AgentStep(this.agentName, this.description, this.icon);
}
