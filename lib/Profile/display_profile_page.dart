import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_app/challenge/challenge_detail_page.dart';

class Challenge {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'],
      title: json['name'] ?? 'Untitled Challenge',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

final otherUserProfileProvider = FutureProvider.family<Profile?, String>((ref, userId) async {
  final supabase = Supabase.instance.client;
  try {
    final data = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

    if (data == null) return null;
    return Profile(
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      points: data['points'] ?? 0,
      avatar: data['avatar'] ?? '',
    );
  } catch (e) {
    print('Error fetching user profile: $e');
    return null;
  }
});

final userChallengesProvider = FutureProvider.family<List<Challenge>, String>((ref, userId) async {
  final supabase = Supabase.instance.client;
  try {
    final data = await supabase
        .from('challenges')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((item) => Challenge.fromJson(item)).toList();
  } catch (e) {
    print('Error fetching user challenges: $e');
    return [];
  }
});

final isFollowingProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;

  if (currentUserId == null) return false;

  final data = await supabase
      .from('followers')
      .select('id')
      .eq('follower_id', currentUserId)
      .eq('following_id', userId)
      .maybeSingle();

  return data != null;
});

final followUserProvider = StateProvider.family<bool, String>((ref, userId) => false);

final followerCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final supabase = Supabase.instance.client;

  final count = await supabase
      .from('followers')
      .count()
      .eq('following_id', userId);

  return count;
});

final followingCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final supabase = Supabase.instance.client;

  final count = await supabase
      .from('followers')
      .count()
      .eq('follower_id', userId);

  return count;
});

class ViewProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const ViewProfilePage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends ConsumerState<ViewProfilePage> {
  late RealtimeChannel _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = Supabase.instance.client
        .channel('public:followers')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'followers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'following_id',
        value: widget.userId,
      ),
      callback: (payload) {
        ref.refresh(followerCountProvider(widget.userId));
        ref.refresh(followingCountProvider(widget.userId));
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription.unsubscribe();
    super.dispose();
  }

  String? _getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;

    try {
      return Supabase.instance.client.storage
          .from('avatar')
          .getPublicUrl(avatarPath);
    } catch (e) {
      print('Error getting avatar URL: $e');
      return null;
    }
  }

  Widget _buildAvatarWidget(String? avatarPath) {
    final avatarUrl = _getAvatarUrl(avatarPath);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
      ),
      child: CircleAvatar(
        radius: 45,
        backgroundColor: const Color(0xFFF5F5F5),
        child: avatarUrl != null
            ? ClipOval(
          child: Image.network(
            avatarUrl,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: const Color(0xFF555555),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading avatar image: $error');
              return const Icon(
                Icons.person,
                size: 40,
                color: Color(0xFF555555),
              );
            },
          ),
        )
            : const Icon(
          Icons.person,
          size: 40,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  Future<void> _toggleFollow(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to follow users')),
      );
      return;
    }
    final isFollowing = ref.read(followUserProvider(widget.userId));

    try {
      if (isFollowing) {
        await supabase
            .from('followers')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.userId);
      } else {
        await supabase
            .from('followers')
            .insert({
          'follower_id': currentUserId,
          'following_id': widget.userId,
        });
      }

      ref.read(followUserProvider(widget.userId).notifier).state = !isFollowing;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(otherUserProfileProvider(widget.userId));
    final challengesAsync = ref.watch(userChallengesProvider(widget.userId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
    final isFollowing = ref.watch(followUserProvider(widget.userId));
    final followerCountAsync = ref.watch(followerCountProvider(widget.userId));
    final followingCountAsync = ref.watch(followingCountProvider(widget.userId));

    const Color background = Colors.white;
    const Color textColor = Colors.black;
    const Color secondaryText = Color(0xFF555555);
    const Color surfaceColor = Color(0xFFF5F5F5);
    const Color borderColor = Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: background,
        foregroundColor: textColor,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatarWidget(profile.avatar),

                  const SizedBox(height: 20),

                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  isFollowingAsync.when(
                    data: (isCurrentlyFollowing) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(followUserProvider(widget.userId).notifier).state = isCurrentlyFollowing;
                      });
                      return Container(
                        width: 140,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: textColor,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: isFollowing ? textColor : background,
                          borderRadius: BorderRadius.circular(3),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(3),
                            onTap: () => _toggleFollow(context),
                            child: Center(
                              child: Text(
                                isFollowing ? 'Unfollow' : 'Follow',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isFollowing ? background : textColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => Container(
                      width: 140,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

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

                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        profile.bio,
                        style: const TextStyle(
                          fontSize: 15,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Challenges",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  challengesAsync.when(
                    data: (challenges) {
                      if (challenges.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          alignment: Alignment.center,
                          child: const Text(
                            "No challenges yet",
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 15,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: challenges.length,
                        itemBuilder: (context, index) {
                          final challenge = challenges[index];
                          return _buildMinimalistChallengeCard(challenge, context);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textColor,
                        ),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error loading challenges',
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: textColor,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error loading profile',
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    );
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

  Widget _buildMinimalistChallengeCard(Challenge challenge, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          borderRadius: BorderRadius.circular(3),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChallengeDetailPage(
                  challengeId: challenge.id,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF555555),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(challenge.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}






