import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  final Color themeColor;
  const AboutUsScreen({super.key, this.themeColor = const Color(0xFF1565C0)});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note, size: 72, color: themeColor),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Darbar Orchestra',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
            const Center(
              child: Text(
                'Smart Service Orchestration Platform',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Our Vision',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Darbar Orchestra brings harmony to home and business services. Just like an orchestra combines different instruments to play a beautiful symphony, Darbar orchestrates and unites certified service providers with customers seamlessly using advanced AI intelligence.',
              style: TextStyle(fontSize: 15, height: 1.5, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 24),
            Text(
              'How It Works',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              context: context,
              icon: Icons.psychology_outlined,
              title: 'AI Orchestrated Matching',
              desc: 'State-of-the-art AI agents extract customer intent and directly dispatch the top-ranked local providers.',
            ),
            _buildFeatureRow(
              context: context,
              icon: Icons.gpp_good_outlined,
              title: 'Verified Partners Only',
              desc: 'Every service provider is strictly vetted with certificates, background checks, and rating reviews.',
            ),
            _buildFeatureRow(
              context: context,
              icon: Icons.speed_outlined,
              title: 'Instant Booking & Alerts',
              desc: 'Book instant services and receive real-time notifications when your provider is accepted, confirmed, or on the way.',
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Version 1.2.0 • Made with ❤️ by Google DeepMind team',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({required BuildContext context, required IconData icon, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: themeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7), fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContactUsScreen extends StatefulWidget {
  final Color themeColor;
  const ContactUsScreen({super.key, this.themeColor = const Color(0xFF1565C0)});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSending = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _isSending = false);
          _emailController.clear();
          _messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent successfully! We will contact you soon.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get In Touch',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Have any queries, suggestions, or issues? Write to us directly.',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Contact Info Cards
            Row(
              children: [
                _buildInfoCard(icon: Icons.email, title: 'Email', value: 'support@darbar.com'),
                const SizedBox(width: 12),
                _buildInfoCard(icon: Icons.phone, title: 'Phone', value: '+92 300 1234567'),
              ],
            ),
            const SizedBox(height: 24),

            // Message Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Your Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your Query / Feedback',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write your message' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSending ? null : _sendMessage,
                      child: _isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Send Message',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: widget.themeColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.themeColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: widget.themeColor, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7), fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class FaqScreen extends StatelessWidget {
  final Color themeColor;
  const FaqScreen({super.key, this.themeColor = const Color(0xFF1565C0)});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I request a service provider?',
        'a': 'Simply go to the Chat tab, type what you need (e.g. "I need an AC technician tomorrow at G-11 Karachi"), and our AI Orchestrator will analyze the intent and suggest verified providers instantly.'
      },
      {
        'q': 'How is the service provider rating calculated?',
        'a': 'Ratings are dynamically updated on the provider profile after a customer marks a booking as completed and submits a review (from 1 to 5 stars).'
      },
      {
        'q': 'How many service gigs can a provider publish?',
        'a': 'To ensure high quality, each service provider can publish up to a maximum of 6 service gigs at any given time.'
      },
      {
        'q': 'Are there any registration fees for providers?',
        'a': 'No, Darbar is currently 100% free to join and register for all verified service partners.'
      },
      {
        'q': 'Who marks the job as completed?',
        'a': 'The service provider marks the booking as completed from their requests dashboard once the work is physically done.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ & Help', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: faqs.length,
        itemBuilder: (ctx, index) {
          final faq = faqs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: Text(
                faq['q']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Text(
                  faq['a']!,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), fontSize: 14, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
