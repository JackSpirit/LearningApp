import 'package:learning_app/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:learning_app/pages/register_page.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // get auth service
  final authService = AuthService();

  // text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();


  // login button pressed
  void login() async {
    // prepare data
    final email = _emailController.text;
    final password = _passwordController.text;
    // attempt login..
    try {
      await authService.signInWithEmailPassword(email, password);
    }

// catch any errors..
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

  }
  void signUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }



  // BUILD UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12 ,vertical: 50),
        children: [
          // email
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText:"Email"),
          ),

          // password
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText:"Password"),
          ),



          const SizedBox(height: 12),
          // button
          ElevatedButton(
            onPressed: login,
            child: const Text("Login"),
          ),
          GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context)=> const RegisterPage())),
              child: const Center(child:Text("Don't have an account?Sign Up") )),// ElevatedButton

        ],
      ),
    );
  }



}
