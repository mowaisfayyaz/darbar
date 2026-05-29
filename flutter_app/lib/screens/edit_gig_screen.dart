import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';

class EditGigScreen extends StatefulWidget {
  final String providerId;
  final Map<String, dynamic>? gig; // Null if creating, non-null if editing

  const EditGigScreen({
    super.key,
    required this.providerId,
    this.gig,
  });

  @override
  State<EditGigScreen> createState() => _EditGigScreenState();
}

class _EditGigScreenState extends State<EditGigScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _timeController;
  
  List<String> _photos = [];
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final gig = widget.gig;
    _titleController = TextEditingController(text: gig?['title'] ?? '');
    _descController = TextEditingController(text: gig?['description'] ?? '');
    _minPriceController = TextEditingController(text: gig != null ? gig['price_min'].toString() : '1000');
    _maxPriceController = TextEditingController(text: gig != null ? gig['price_max'].toString() : '5000');
    _timeController = TextEditingController(text: gig?['estimated_time'] ?? '1-2 Days');
    
    if (gig != null && gig['photos'] != null) {
      _photos = List<String>.from(gig['photos']);
    }
    _isActive = gig?['is_active'] ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isLoading = true);
      final bytes = await image.readAsBytes();
      final url = await _api.uploadImage(bytes, image.name);
      
      setState(() {
        _photos.add(url);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo added successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveGig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final data = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'photos': _photos,
      'price_min': int.tryParse(_minPriceController.text) ?? 0,
      'price_max': int.tryParse(_maxPriceController.text) ?? 0,
      'estimated_time': _timeController.text.trim(),
      'is_active': _isActive,
    };

    try {
      if (widget.gig != null) {
        // Edit existing
        await _api.editProviderGig(widget.providerId, widget.gig!['id'], data);
      } else {
        // Create new
        await _api.createProviderGig(widget.providerId, data);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save gig: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    final isEditMode = widget.gig != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Service Gig' : 'Add New Service Gig'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Gig Title',
                      hintText: 'e.g. Professional AC Repair & Gas Refill',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Gig Description',
                      hintText: 'Describe the scope of service, what is included, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min Price (PKR)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Price (PKR)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Completion Time',
                      hintText: 'e.g. 2-4 Hours, 1 Day',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Photos grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gig Photos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _pickAndUploadPhoto,
                        icon: const Icon(Icons.add_a_photo, color: Colors.green),
                        label: const Text('Add Photo', style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_photos.isEmpty)
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('No photos added yet. Upload high quality gig covers.'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        itemBuilder: (ctx, idx) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_photos[idx]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 16,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _photos.removeAt(idx);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Active'),
                    subtitle: const Text('Allow clients to see and book this gig'),
                    value: _isActive,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveGig,
                      child: Text(
                        isEditMode ? 'Save Changes' : 'Create Gig',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
