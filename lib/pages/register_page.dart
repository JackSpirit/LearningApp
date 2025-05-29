import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_app/pages/home_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String? _avatarPath;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_selectedImage == null || _imageBytes == null) return null;

    try {
      setState(() => _uploadingImage = true);

      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('avatar')
          .uploadBinary(
        fileName,
        _imageBytes!,
        fileOptions: FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '3600',
          upsert: true,
        ),
      );

      setState(() => _uploadingImage = false);
      return fileName;
    } catch (e) {
      setState(() => _uploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading avatar: $e")),
        );
      }
      print('Upload error details: $e');
      return null;
    }
  }

  void signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final int points = 0;

    if (password != confirmPassword) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords don't match")));
      return;
    }

    try {
      await authService.signUpWithEmailPassword(email, password);

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("User ID not found after sign up")));
        return;
      }

      String? avatarPath;
      if (_selectedImage != null) {
        avatarPath = await _uploadAvatar(userId);
      }

      // Insert profile data
      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'name': name,
        'bio': bio,
        'points': points,
        'avatar': avatarPath,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void goToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: "Email",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.emailAddress,
                ),
                const Divider(height: 1, thickness: 1),

                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    hintText: "Password",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(height: 1, thickness: 1),

                TextField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    hintText: "Confirm Password",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(height: 1, thickness: 1),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: "Name",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(height: 1, thickness: 1),

                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    hintText: "Bio",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(height: 1, thickness: 1),

                // Avatar Upload Section
                const SizedBox(height: 24),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : null,
                      child: _imageBytes == null
                          ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _uploadingImage ? null : _pickImage,
                      icon: _uploadingImage
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.camera_alt),
                      label: Text(_uploadingImage
                          ? "Uploading..."
                          : "Choose Avatar"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: signUp,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Sign Up", style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: goToLogin,
                  child: Text(
                    "Back to Login",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}






