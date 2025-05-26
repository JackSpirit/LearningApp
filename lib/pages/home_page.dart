import 'package:flutter/material.dart';
import 'package:learning_app/pages/profile_page.dart';
import 'package:learning_app/Challenge/create_challenge_page.dart';
import 'package:learning_app/Profile/search_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_app/Challenge/challenge_enter_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> enteredChallenges = [];
  bool isLoading = true;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadEnteredChallenges();
  }

  Future<void> loadEnteredChallenges() async {
    setState(() {
      isLoading = true;
    });

    try {
      await deleteExpiredChallenges();

      final prefs = await SharedPreferences.getInstance();
      final challengeIds = prefs.getStringList('enteredChallenges') ?? [];

      final challenges = <Map<String, String>>[];
      final validChallengeIds = <String>[];

      for (final id in challengeIds) {
        final challengeData = await fetchChallengeFromBackend(id);

        if (challengeData != null) {
          final endTime = DateTime.parse(challengeData['end_time']);
          if (endTime.isAfter(DateTime.now())) {
            challenges.add({
              'id': id,
              'name': challengeData['name'] ?? 'Challenge $id',
            });
            validChallengeIds.add(id);

            await prefs.setString('challenge_name_$id', challengeData['name'] ?? '');
          } else {
             await removeLocalChallengeData(id);
          }
        } else {
          await removeLocalChallengeData(id);
        }
      }

      await prefs.setStringList('enteredChallenges', validChallengeIds);

      setState(() {
        enteredChallenges = challenges;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteExpiredChallenges() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final expiredChallenges = await _supabase
          .from('challenges')
          .select('id')
          .eq('user_id', userId)
          .lt('end_time', DateTime.now().toIso8601String());

      for (final challenge in expiredChallenges) {
        final challengeId = challenge['id'];

        await _supabase
            .from('tasks')
            .delete()
            .eq('challenge_id', challengeId);

        await _supabase
            .from('challenges')
            .delete()
            .eq('id', challengeId);

        print('Deleted expired challenge: $challengeId');
      }
    } catch (e) {
      print('Error deleting expired challenges: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchChallengeFromBackend(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenges')
          .select('id, name, end_time')
          .eq('id', challengeId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching challenge: $e');
      return null;
    }
  }

  Future<bool> checkChallengeExistsInBackend(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenges')
          .select('id')
          .eq('id', challengeId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking challenge existence: $e');
      return false;
    }
  }

  Future<void> removeLocalChallengeData(String challengeId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('challenge_name_$challengeId');
    await prefs.remove('challenge_description_$challengeId');
    await prefs.remove('challenge_duration_$challengeId');
    await prefs.remove('challenge_start_date_$challengeId');
    await prefs.remove('challenge_progress_$challengeId');

    print('Removed local data for deleted/expired challenge: $challengeId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
          },
          icon: const Icon(
            Icons.person_outline,
            color: Colors.black,
            size: 28,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileSearchPage()),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: AbsorbPointer(
                        child: TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (enteredChallenges.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    height: 20,
                    width: 4,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MY CHALLENGES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 120,
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
                              challengeId: challenge['id']!,
                            ),
                          ),
                        ).then((_) {
                          loadEnteredChallenges();
                        });
                      },
                      child: Container(
                        width: 150,
                        margin: EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                challenge['name']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            Expanded(
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  strokeWidth: 2,
                ),
              )
                  : enteredChallenges.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_score_outlined,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No challenges yet',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create or enter a challenge to get started',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : const SizedBox(),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateChallengePage()),
                  ).then((_) {
                    loadEnteredChallenges();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'CREATE CHALLENGE',
                  style: TextStyle(
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


