import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'edit_gig_screen.dart';

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
        // Update local state and backend immediately or on save
        setState(() {
          _providerData['profile_photo'] = imageUrl;
        });
        await _api.updateProviderProfile(widget.providerId, {
          'profile_photo': imageUrl,
        });
      } else {
        setState(() {
          _experienceData['cert_image'] = imageUrl;
        });
        await _api.updateProviderProfile(widget.providerId, {
          'cert_image': imageUrl,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green),
      );
      _loadProfile();
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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
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

  Widget _buildGigsSection(bool isDark) {
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
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditGigScreen(providerId: widget.providerId),
                      ),
                    );
                    if (res == true) _loadProfile();
                  },
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
              itemCount: _gigs.length,
              itemBuilder: (ctx, idx) {
                final gig = _gigs[idx];
                final photos = gig['photos'] as List?;
                final photoUrl = (photos != null && photos.isNotEmpty) ? photos.first : '';

                return Container(
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
            ElevatedButton.icon(
              onPressed: () => _pickAndUploadImage(isProfilePhoto: false),
              icon: const Icon(Icons.upload),
              label: const Text('Upload Certificate Photo'),
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
          const Text('Customer Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_reviews.isEmpty)
            const Center(child: Text('No reviews yet.'))
          else
            ..._reviews.map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r['user_name'] ?? 'Customer'),
              subtitle: Text(r['comment'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('${r['rating'] ?? 5}'),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
