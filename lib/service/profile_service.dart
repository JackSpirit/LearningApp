import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/profile.dart';
import 'dart:io';

class ProfileService {
  final _client = Supabase.instance.client;

  Future<Profile?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<void> updateProfile(String userId, Profile profile) async {
    await _client.from('profiles').upsert({'id': userId, ...profile.toMap()});
  }

  Future<String> uploadAvatar(String userId, String filePath) async {
    final file = File(filePath);
    await _client.storage.from('avatars').upload(
      '$userId.png',
      file,
      fileOptions: const FileOptions(upsert: true),
    );
    return _client.storage.from('avatars').getPublicUrl('$userId.png');
  }
}

