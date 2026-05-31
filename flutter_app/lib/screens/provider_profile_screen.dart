import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'edit_gig_screen.dart';
import 'app_drawer.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final bool isEditable; // True if logged-in provider, false if customer view

  const ProviderProfileScreen({
    super.key,
    required this.providerId,
    required this.isEditable,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;

  // Profile data state
  Map<String, dynamic> _providerData = {};
  List<dynamic> _gigs = [];
  List<dynamic> _discounts = [];
  Map<String, dynamic> _experienceData = {};
  List<dynamic> _reviews = [];

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _cityController;
  late TextEditingController _areaController;
  late TextEditingController _expController;
  late TextEditingController _certController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _categoryController = TextEditingController();
    _cityController = TextEditingController();
    _areaController = TextEditingController();
    _expController = TextEditingController();
    _certController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _expController.dispose();
    _certController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getProviderProfile(widget.providerId);
      setState(() {
        _providerData = data['provider'] ?? {};
        _gigs = data['gigs'] ?? [];
        _discounts = data['discounts'] ?? [];
        _experienceData = data['experience'] ?? {};
        _reviews = data['reviews'] ?? [];
        
        _nameController.text = _providerData['business_name'] ?? '';
        _categoryController.text = _providerData['category'] ?? '';
        _cityController.text = _providerData['city'] ?? '';
        _areaController.text = _providerData['area'] ?? '';
        _expController.text = (_providerData['years_of_experience'] ?? 0).toString();
        _certController.text = _experienceData['certifications'] ?? '';
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage({required bool isProfilePhoto}) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() => _isLoading = true);

      final imageUrl = await _api.uploadImage(bytes, image.name);

      if (isProfilePhoto) {
        setState(() {
          _providerData['profile_photo'] = imageUrl;
          _isLoading = false;
        });
      } else {
        setState(() {
          _experienceData['cert_image'] = imageUrl;
          _isLoading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded! Click "Save Profile Changes" below to save.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isLoading = true);
    try {
      final int yrs = int.tryParse(_expController.text) ?? 0;
      await _api.updateProviderProfile(widget.providerId, {
        'business_name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'city': _cityController.text.trim(),
        'area': _areaController.text.trim(),
        'years_of_experience': yrs,
        'certifications': _certController.text.trim(),
        'profile_photo': _providerData['profile_photo'] ?? '',
        'cert_image': _experienceData['cert_image'] ?? '',
      });

      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
      );
      _loadProfile();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _manageDiscountBanner() async {
    final titleController = TextEditingController(
      text: _discounts.isNotEmpty ? _discounts.first['title'] : '',
    );
    final percentController = TextEditingController(
      text: _discounts.isNotEmpty ? _discounts.first['discount_percent'].toString() : '10',
    );
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_discounts.isNotEmpty ? 'Edit Discount Banner' : 'Create Discount Banner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Promo Message (e.g. Summer Sale)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: percentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Discount Percentage (%)'),
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
                  final daysValid = DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
                  await _api.manageDiscounts(widget.providerId, {
                    'title': titleController.text.trim(),
                    'discount_percent': int.tryParse(percentController.text) ?? 10,
                    'valid_until': daysValid,
                    'is_active': true,
                  });
                  _loadProfile();
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save discount: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: widget.isEditable ? const AppDrawer(isProviderTheme: true) : null,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: widget.isEditable
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: Text(_isEditing ? 'Edit Profile' : 'Business Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isEditable)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveProfileChanges();
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderSection(isDark),
            if (_discounts.isNotEmpty) _buildDiscountBannerSection(isDark),
            _buildStatsBar(isDark),
            _buildGigsSection(isDark),
            _buildExperienceSection(isDark),
            _buildReviewsSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark) {
    final photoUrl = _providerData['profile_photo'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.green.shade100,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.business, size: 60, color: Colors.green)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadImage(isProfilePhoto: true),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isEditing) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _areaController,
                    decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              _providerData['business_name'] ?? 'Loading...',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(_providerData['category'] ?? 'Service Provider'),
              backgroundColor: Colors.green.withOpacity(0.1),
              labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_providerData['area'] ?? ''}, ${_providerData['city'] ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDiscountBannerSection(bool isDark) {
    final discount = _discounts.first;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discount['title'] ?? 'Special Promo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Get ${discount['discount_percent']}% off on bookings now!',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          if (widget.isEditable && _isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: _manageDiscountBanner,
            )
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCol('Rating', '${_providerData['rating'] ?? 0.0} ⭐'),
          _statCol('Reviews', '${_providerData['review_count'] ?? 0}'),
          _statCol('Experience', '${_providerData['years_of_experience'] ?? 0} yrs'),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  void _showGigDetails(dynamic gig) {
    final photos = gig['photos'] as List?;
    final photoUrl = (photos != null && photos.isNotEmpty) ? photos.first : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 180,
                                  width: double.infinity,
                                  color: Colors.green.shade50,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.green),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  width: double.infinity,
                                  color: Colors.green.shade50,
                                  child: const Icon(Icons.broken_image, color: Colors.green, size: 64),
                                );
                              },
                            )
                          : Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.green.shade50,
                              child: const Icon(Icons.image, color: Colors.green, size: 64),
                            ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gig['title'] ?? 'Service Gig',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'PKR ${gig['price_min']} - PKR ${gig['price_max']}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                gig['estimated_time'] ?? 'Flexible',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        gig['description'] ?? 'No description provided.',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllGigsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('All Service Gigs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _gigs.length,
                itemBuilder: (context, index) {
                  final gig = _gigs[index];
                  final photos = gig['photos'] as List?;
                  final photoUrl = (photos != null && photos.isNotEmpty) ? photos.first : '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: photoUrl.isNotEmpty
                            ? Image.network(photoUrl, width: 60, height: 60, fit: BoxFit.cover)
                            : Container(width: 60, height: 60, color: Colors.green.shade50, child: const Icon(Icons.image, color: Colors.green)),
                      ),
                      title: Text(gig['title'] ?? 'Service Gig', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('PKR ${gig['price_min']} - ${gig['price_max']} • ${gig['estimated_time'] ?? 'Flexible'}'),
                      onTap: () {
                        Navigator.pop(context);
                        _showGigDetails(gig);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllReviewsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('All Customer Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final r = _reviews[index];
                  return _buildReviewTile(r, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(dynamic r, bool isDark) {
    final rating = r['rating'] ?? 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(Icons.person, size: 16, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r['user_name'] ?? 'Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r['comment'] ?? '',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildGigsSection(bool isDark) {
    final bool hasMoreThan3 = _gigs.length > 3;
    final int displayCount = hasMoreThan3 ? 4 : _gigs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Service Gigs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (widget.isEditable && _isEditing)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () async {
                    if (_gigs.length >= 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Limit reached: You can add a maximum of 6 gigs.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditGigScreen(providerId: widget.providerId),
                      ),
                    );
                    if (res == true) _loadProfile();
                  },
                )
              else if (hasMoreThan3)
                TextButton(
                  onPressed: _showAllGigsSheet,
                  child: const Text('See All', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        if (_gigs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No gigs offered yet.')),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayCount,
              itemBuilder: (ctx, idx) {
                if (hasMoreThan3 && idx == 3) {
                  return InkWell(
                    onTap: _showAllGigsSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 16, bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: const Icon(Icons.arrow_forward, color: Colors.green),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'See All Gigs',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_gigs.length - 3} more gigs',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final gig = _gigs[idx];
                final photos = gig['photos'] as List?;
                final photoUrl = (photos != null && photos.isNotEmpty) ? photos.first : '';

                return InkWell(
                  onTap: () => _showGigDetails(gig),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 16, bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: photoUrl.isNotEmpty
                              ? Image.network(photoUrl, height: 110, width: double.infinity, fit: BoxFit.cover)
                              : Container(height: 110, color: Colors.green.shade50, child: const Icon(Icons.image, color: Colors.green)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gig['title'] ?? 'Service Gig',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PKR ${gig['price_min']} - PKR ${gig['price_max']}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    gig['estimated_time'] ?? 'Flexible',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.isEditable && _isEditing)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditGigScreen(
                                        providerId: widget.providerId,
                                        gig: gig,
                                      ),
                                    ),
                                  );
                                  if (res == true) _loadProfile();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete Gig?'),
                                      content: const Text('Are you sure you want to delete this service gig?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    setState(() => _isLoading = true);
                                    await _api.deleteProviderGig(widget.providerId, gig['id']);
                                    _loadProfile();
                                  }
                                },
                              ),
                            ],
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildExperienceSection(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Experience & Certifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isEditing) ...[
            TextField(
              controller: _expController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years of Experience'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _certController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Certifications / Credentials'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndUploadImage(isProfilePhoto: false),
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Certificate Photo'),
                  ),
                ),
              ],
            ),
            if ((_experienceData['cert_image'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_experienceData['cert_image']),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveProfileChanges,
              child: const Text('Save Profile Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.star_border, color: Colors.green),
                const SizedBox(width: 8),
                Text('${_providerData['years_of_experience'] ?? 0} Years in Business'),
              ],
            ),
            const SizedBox(height: 12),
            if ((_experienceData['certifications'] ?? '').isNotEmpty) ...[
              const Text('Certifications:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_experienceData['certifications'] ?? ''),
            ],
            const SizedBox(height: 12),
            if ((_experienceData['cert_image'] ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_experienceData['cert_image']),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsSection(bool isDark) {
    final bool hasMoreThan3 = _reviews.length > 3;
    final int displayCount = hasMoreThan3 ? 3 : _reviews.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (hasMoreThan3)
                TextButton(
                  onPressed: _showAllReviewsSheet,
                  child: const Text('See All', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_reviews.isEmpty)
            const Center(child: Text('No reviews yet.'))
          else ...[
            ..._reviews.take(displayCount).map((r) => _buildReviewTile(r, isDark)),
            if (hasMoreThan3) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showAllReviewsSheet,
                  child: Text(
                    'See All ${_reviews.length} Reviews',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
