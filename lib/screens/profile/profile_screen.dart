import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;
  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).refreshUser();
    });
  }

  Future<void> _saveProfilePhoto(String path) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.updateProfilePhotoPath(path);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        await _saveProfilePhoto(image.path);
        return;
      }
    } catch (e) {
      debugPrint('image_picker failed, trying file_picker fallback: $e');
      if (source == ImageSource.gallery) {
        try {
          final FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
          );
          if (result != null && result.files.single.path != null) {
            await _saveProfilePhoto(result.files.single.path!);
            return;
          }
        } catch (fallbackError) {
          debugPrint('FilePicker fallback also failed: $fallbackError');
        }
      }
      
      if (mounted) {
        String msg = 'Failed to pick image: $e';
        if (e.toString().contains('MissingPluginException')) {
          msg = 'Please STOP the running app and re-run "flutter run" to complete package installation!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.amberAccent,
              onPressed: _showRebuildDialog,
            ),
          ),
        );
      }
    }
  }

  void _showRebuildDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: Color(0xFF3F51B5)),
            SizedBox(width: 8),
            Text('App Rebuild Required'),
          ],
        ),
        content: const Text(
          'Since a new package (image_picker) was just added, Flutter must compile its native Android/iOS components.\n\n'
          'To fix this immediately, stop the current "flutter run" command in your terminal/editor and run it again!',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWidget(double radius) {
    final photoPath = Provider.of<AuthProvider>(context).profilePhotoPath;
    if (photoPath == null || photoPath.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
        child: Icon(Icons.person, size: radius, color: const Color(0xFF3F51B5)),
      );
    }

    final file = File(photoPath);
    if (!file.existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
        child: Icon(Icons.person, size: radius, color: const Color(0xFF3F51B5)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        file,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.red.shade50,
            child: Icon(Icons.broken_image, size: radius * 0.8, color: Colors.red.shade300),
          );
        },
      ),
    );
  }

  void _showPhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentPhotoPath = Provider.of<AuthProvider>(context).profilePhotoPath;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Update Profile Photo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'SELECT AN OPTION TO UPLOAD YOUR PHOTO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F51B5).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.12)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.camera_alt_rounded, color: Color(0xFF3F51B5), size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Take Photo',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F51B5).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.12)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.photo_library_rounded, color: Color(0xFF3F51B5), size: 32),
                            SizedBox(height: 8),
                            Text(
                              'From Gallery',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (currentPhotoPath != null && currentPhotoPath.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      _saveProfilePhoto('');
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    label: const Text(
                      'Remove Current Photo',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditEmailSheet(String currentEmail) {
    final emailController = TextEditingController(text: currentEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Update Email Address',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final newEmail = emailController.text.trim();
                    if (newEmail.isNotEmpty) {
                      await Provider.of<AuthProvider>(context, listen: false)
                          .updateUserEmail(newEmail);
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F51B5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Update Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final String userRole = user?.role.toLowerCase() ?? 'dse';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              centerTitle: true,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => auth.refreshUser(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 110.0),
          child: Column(
            children: [
              // Profile Photo & Role Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200, width: 2),
                          ),
                          child: _buildPhotoWidget(50),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _showPhotoPickerSheet,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF3F51B5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.role.toUpperCase() ?? 'ROLE',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Personal Information Section
              _buildSectionHeader('Personal Information'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildRowItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: user?.name ?? 'Not Available',
                      isEditable: false,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                    _buildRowItem(
                      icon: Icons.phone_android_rounded,
                      label: 'Phone Number',
                      value: user?.phone ?? 'Not Available',
                      isEditable: false,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                    _buildRowItem(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: (user?.email == null || user!.email!.isEmpty)
                          ? 'Add Email Address'
                          : user.email!,
                      isEditable: true,
                      onEditTap: () => _showEditEmailSheet(user?.email ?? ''),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Employment Details Section
              _buildSectionHeader('Employment Details'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildRowItem(
                      icon: Icons.badge_outlined,
                      label: 'Employee ID',
                      value: user?.id ?? 'Not Available',
                      isEditable: false,
                    ),
                    if (userRole == 'dse') ...[
                      Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                      _buildRowItem(
                        icon: Icons.supervised_user_circle_outlined,
                        label: 'Team Leader',
                        value: (user?.tlName == null || user!.tlName!.isEmpty)
                            ? 'Not Assigned'
                            : user.tlName!,
                        isEditable: false,
                      ),
                    ] else if (userRole == 'tl') ...[
                      Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                      _buildRowItem(
                        icon: Icons.manage_accounts_outlined,
                        label: 'Assigned Manager',
                        value: (user?.managerId == null || user!.managerId!.isEmpty)
                            ? 'Admin Manager'
                            : 'Manager (ID: ${user.managerId})',
                        isEditable: false,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    foregroundColor: const Color(0xFFDC2626),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hi-Tech App • Version 1.0.3',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isEditable,
    VoidCallback? onEditTap,
  }) {
    final isPlaceholder = value.startsWith('Add ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3F51B5).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3F51B5), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isPlaceholder ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF3F51B5),
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
