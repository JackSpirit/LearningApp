import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../provider/profile_provider.dart';
import '../model/profile.dart';
import 'login_page.dart';
import '../auth/auth_service.dart';
import 'package:learning_app/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final followerCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;

  if (currentUserId == null) return 0;

  final count = await supabase
      .from('followers')
      .count()
      .eq('following_id', currentUserId);

  return count;
});

final followingCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;

  if (currentUserId == null) return 0;

  final count = await supabase
      .from('followers')
      .count()
      .eq('follower_id', currentUserId);

  return count;
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  File? _imageFile;

  final authService = AuthService();

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
    await authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  Widget _buildStatContainer({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final followerCountAsync = ref.watch(followerCountProvider);
    final followingCountAsync = ref.watch(followingCountProvider);

    const Color background = Colors.white;
    const Color textColor = Colors.black;
    const Color secondaryText = Color(0xFF888888);
    const Color borderColor = Colors.black12;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        title: Text('Profile'),
        backgroundColor: Colors.white,
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

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: followerCountAsync.when(
                          data: (count) => _buildStatContainer(
                            icon: Icons.people_outline,
                            label: "Followers",
                            value: count.toString(),
                          ),
                          loading: () => _buildStatContainer(
                            icon: Icons.people_outline,
                            label: "Followers",
                            value: "...",
                          ),
                          error: (_, __) => _buildStatContainer(
                            icon: Icons.people_outline,
                            label: "Followers",
                            value: "0",
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _buildStatContainer(
                          icon: Icons.star_outline,
                          label: "Points",
                          value: profile.points.toString(),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: followingCountAsync.when(
                          data: (count) => _buildStatContainer(
                            icon: Icons.person_add_outlined,
                            label: "Following",
                            value: count.toString(),
                          ),
                          loading: () => _buildStatContainer(
                            icon: Icons.person_add_outlined,
                            label: "Following",
                            value: "...",
                          ),
                          error: (_, __) => _buildStatContainer(
                            icon: Icons.person_add_outlined,
                            label: "Following",
                            value: "0",
                          ),
                        ),
                      ),
                    ],
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








