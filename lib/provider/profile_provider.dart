import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/profile.dart';
import '../service/profile_service.dart';

final profileServiceProvider = Provider((_) => ProfileService());

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<Profile?>>(
      (ref) => ProfileNotifier(ref),
);

class ProfileNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final Ref ref;  // <--- FIXED HERE

  ProfileNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final profile = await ref.read(profileServiceProvider).fetchProfile(userId); // <--- FIXED HERE
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(Profile profile) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await ref.read(profileServiceProvider).updateProfile(userId!, profile); // <--- FIXED HERE
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAvatar(String filePath) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final url = await ref.read(profileServiceProvider).uploadAvatar(userId!, filePath); // <--- FIXED HERE
      final current = state.value;
      if (current != null) {
        final updated = Profile(
          name: current.name,
          bio: current.bio,
          points: current.points,
          avatarUrl: url,
        );
        await updateProfile(updated);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}


