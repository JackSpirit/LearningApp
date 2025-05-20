import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _avatarUrlController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();
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

      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'name': name,
        'bio': bio,
        'points': points,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context);
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

              TextField(
                controller: _avatarUrlController,
                decoration: const InputDecoration(
                  hintText: "Avatar URL",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const Divider(height: 1, thickness: 1),

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
    );
  }
}



