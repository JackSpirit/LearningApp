import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardEntry {
  final String name;
  final int points;
  final String? avatarUrl;

  LeaderboardEntry({
    required this.name,
    required this.points,
    this.avatarUrl,
  });
}

class LeaderBoard extends StatefulWidget {
  const LeaderBoard({super.key});

  @override
  State<LeaderBoard> createState() => _LeaderBoardState();
}

class _LeaderBoardState extends State<LeaderBoard> {
  List<LeaderboardEntry> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('profiles')
          .select('name, points, avatar')
          .order('points', ascending: false)
          .limit(100);

      final List<LeaderboardEntry> entries = response.map((item) {
        return LeaderboardEntry(
          name: item['name'] as String? ?? 'Anonymous User',
          points: (item['points'] ?? 0) as int,
          avatarUrl: item['avatar'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _leaderboardData = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load leaderboard. Please try again.";
          debugPrint("Error fetching leaderboard: $e");
        });
      }
    }
  }

  Widget _buildAvatar(LeaderboardEntry entry) {
    if (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty) {
      final String publicUrl = _supabase.storage
          .from('avatar')
          .getPublicUrl(entry.avatarUrl!);

      Uri? uri = Uri.tryParse(publicUrl);
      if (uri != null && uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return CircleAvatar(
          backgroundImage: NetworkImage(publicUrl),
          onBackgroundImageError: (exception, stackTrace) {
            debugPrint('Error loading image from $publicUrl: $exception');
          },
          backgroundColor: Colors.grey[200],
          child: null,
        );
      } else {
        debugPrint('Constructed invalid URL: $publicUrl from path: ${entry.avatarUrl}');
      }
    }
    return CircleAvatar(
      backgroundColor: Colors.grey[300],
      child: Text(
        entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'A',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: _buildLeaderboardContent(),
    );
  }

  Widget _buildLeaderboardContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _fetchLeaderboardData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_leaderboardData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_rounded, size: 60, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'The leaderboard is empty.',
              style: TextStyle(fontSize: 17, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Compete in challenges to see your rank!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaderboardData,
      color: Colors.black,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: _leaderboardData.length,
        itemBuilder: (context, index) {
          final entry = _leaderboardData[index];
          final rank = index + 1;

          IconData? rankIcon;
          Color? rankIconColor;

          if (rank == 1) {
            rankIcon = Icons.emoji_events_rounded;
            rankIconColor = Colors.amber[600];
          } else if (rank == 2) {
            rankIcon = Icons.emoji_events_rounded;
            rankIconColor = Colors.grey[500];
          } else if (rank == 3) {
            rankIcon = Icons.emoji_events_rounded;
            rankIconColor = Colors.brown[400];
          }

          return ListTile(
            leading: SizedBox(
              width: 80,
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: rankIcon != null
                        ? Icon(rankIcon, color: rankIconColor, size: 28)
                        : Text(
                      '#$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildAvatar(entry),
                ],
              ),
            ),
            title: Text(
              entry.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            trailing: Text(
              '${entry.points} pts',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => Divider(height: 1, indent: 80, endIndent: 16, color: Colors.grey[200]),
      ),
    );
  }
}



