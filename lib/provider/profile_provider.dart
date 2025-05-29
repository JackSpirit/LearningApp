import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/profile.dart';
import '../service/profile_service.dart';

final profileServiceProvider = Provider((_) => ProfileService());

final profileProvider =
StateNotifierProvider<ProfileNotifier, AsyncValue<Profile?>>((ref) {
  return ProfileNotifier(ref)..loadProfile();
});

class ProfileNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final Ref ref;

  ProfileNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final profile = await ref.read(profileServiceProvider).fetchProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(Profile profile) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';
      await ref.read(profileServiceProvider).updateProfile(userId, profile);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAvatar(String avatarFileName) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar': avatarFileName})
          .eq('id', userId);
      final current = state.value;
      if (current != null) {
        final updated = Profile(
          name: current.name,
          bio: current.bio,
          points: current.points,
          avatar: avatarFileName,
        );
        state = AsyncValue.data(updated);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    try {
      return Supabase.instance.client.storage
          .from('avatar')
          .getPublicUrl(avatarPath);
    } catch (_) {
      return null;
    }
  }

  String? get currentAvatarUrl {
    final avatarPath = state.value?.avatar;
    return getAvatarUrl(avatarPath);
  }
}










