import 'package:flutter/material.dart';
import 'package:learning_app/pages/profile_page.dart';
import 'package:learning_app/Challenge/create_challenge_page.dart';
import 'package:learning_app/Profile/search_profile_page.dart';
import 'package:learning_app/Challenge/challenge_enter_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_app/Leaderboard/leaderboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> enteredChallenges = [];
  bool isLoading = true;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadEnteredChallenges();
  }

  Future<void> loadEnteredChallenges() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            enteredChallenges = [];
            isLoading = false;
          });
        }
        return;
      }

      final data = await _supabase
          .from('challenge_entries')
          .select('challenge_id, challenges(id, name, end_time)')
          .eq('user_id', userId);

      final List<Map<String, dynamic>> challenges = [];
      for (final entry in data) {
        final challengeData = entry['challenges'];
        if (challengeData != null) {
          final endTime = DateTime.tryParse(challengeData['end_time'] ?? '');
          if (endTime == null || endTime.isAfter(DateTime.now())) {
            challenges.add({
              'id': challengeData['id'],
              'name': challengeData['name'] ?? 'Challenge',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          enteredChallenges = challenges;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading challenges: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading challenges: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _navigateToLeaderBoardPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LeaderBoard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          icon: const Icon(
            Icons.person_outline_rounded,
            color: Colors.black,
            size: 28,
          ),
          tooltip: 'Profile',
          padding: EdgeInsets.zero,
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.leaderboard_rounded,
              color: Colors.black,
              size: 28,
            ),
            tooltip: 'Leaderboard',
            onPressed: _navigateToLeaderBoardPage,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileSearchPage()),
                );
              },
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Text(
                      'Search Users or Challenges',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (!isLoading && enteredChallenges.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    height: 22,
                    width: 5,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MY ACTIVE CHALLENGES',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: enteredChallenges.length,
                  itemBuilder: (context, index) {
                    final challenge = enteredChallenges[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChallengeDetailPage(
                              challengeId: challenge['id'],
                            ),
                          ),
                        ).then((_) {
                          loadEnteredChallenges();
                        });
                      },
                      child: Card(
                        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 2),
                        elevation: 1.5,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                        child: Container(
                          width: 170,
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                challenge['name'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

           Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  strokeWidth: 3,
                ),
              )
                  : enteredChallenges.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Active Challenges',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'Create or join a challenge to see it here!',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 70),
                  ],
                ),
              )
                  : const SizedBox(),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, top:16.0, left:16.0, right:16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  CreateChallengePage()),
                    ).then((_) {
                      loadEnteredChallenges();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  child: const Text('CREATE NEW CHALLENGE'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}








