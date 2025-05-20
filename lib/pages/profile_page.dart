import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../provider/profile_provider.dart';
import '../model/profile.dart';
import 'login_page.dart'; // Make sure this import points to your LoginPage
import '../auth/auth_service.dart'; // Make sure this import points to your AuthService

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  File? _imageFile;

  final authService = AuthService(); // Uses your Supabase AuthService

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
      await ref.read(profileProvider.notifier).updateAvatar(picked.path);
    }
  }

  void _saveProfile(Profile current) async {
    final updated = Profile(
      name: _nameController.text,
      bio: _bioController.text,
      points: current.points,
      avatarUrl: current.avatarUrl,
    );
    await ref.read(profileProvider.notifier).updateProfile(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    }
  }

  Future<void> _signOut() async {
    await authService.signOut(); // Uses your Supabase signOut method
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    // Minimalist black and white palette
    const Color background = Colors.white;
    const Color textColor = Colors.black;
    const Color secondaryText = Color(0xFF888888);
    const Color borderColor = Colors.black12;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: textColor),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('No profile found.'));

          _nameController.text = profile.name;
          _bioController.text = profile.bio;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (profile.avatarUrl.isNotEmpty
                          ? NetworkImage(profile.avatarUrl)
                          : null) as ImageProvider?,
                      child: profile.avatarUrl.isEmpty && _imageFile == null
                          ? const Icon(Icons.person, size: 48, color: Colors.black)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _pickImage,
                    style: TextButton.styleFrom(
                      foregroundColor: textColor,
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    child: const Text("Change Photo"),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 18, color: textColor),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: secondaryText),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 1.5),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.person_outline, color: textColor),
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _bioController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 16, color: textColor),
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      labelStyle: TextStyle(color: secondaryText),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 1.5),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.info_outline, color: textColor),
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: textColor, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          "Points",
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${profile.points}',
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: textColor,
                        foregroundColor: background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        elevation: 0,
                      ),
                      onPressed: () => _saveProfile(profile),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}





