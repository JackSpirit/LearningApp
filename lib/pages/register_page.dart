import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // get auth service
  final authService = AuthService();

  // text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();


  void login() {
    Navigator.pop(context);
  }


  // sign up button pressed
  void signUp() async {
    // prepare data
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // check that passwords match
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords don't match")));
      return;
    }
    // attempt sign up..
    try {
      await authService.signUpWithEmailPassword(email, password);

      // pop this register page
      Navigator.pop(context);
    }

    // catch any errors..
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),

      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12 ,vertical: 50),
        children: [
          // email
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText:"Email"),
          ), // TextField

          // password
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText:"Password"),
          ),

          //confirm password
          TextField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(labelText:"Confirm Password"),
          ),

          const SizedBox(height: 12),
          // button
          ElevatedButton(
            onPressed: signUp,
            child: const Text("Sign Up"),
          ),

        ],
      ),
    );
  }
}
