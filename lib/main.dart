import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';

void main() async {
  await Supabase.initialize(url: "https://sgsrsfvhyltomnznfloz.supabase.co", anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnc3JzZnZoeWx0b21uem5mbG96Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc1NTA2MjMsImV4cCI6MjA2MzEyNjYyM30.xyHiLoTs-nmyFRbye1vGb_Q1S7lGSTHsmgLZ7JKlFmU");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(),
    );
  }
}


