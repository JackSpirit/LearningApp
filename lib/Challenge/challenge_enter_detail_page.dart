import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:learning_app/Discussions/Forum_page.dart';

Future<void> saveEnteredChallenge(String challengeId, String challengeName) async {
  final prefs = await SharedPreferences.getInstance();

  final challenges = prefs.getStringList('enteredChallenges') ?? [];
  if (!challenges.contains(challengeId)) {
    challenges.add(challengeId);
    await prefs.setStringList('enteredChallenges', challenges);
  }

  await prefs.setString('challenge_name_$challengeId', challengeName);
}

Future<void> completeTask(String taskId, int points) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    print('No authenticated user found');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final completedTasks = prefs.getStringList('completedTasks') ?? [];
  if (completedTasks.contains(taskId)) {
    return;
  }

  try {
    final response = await supabase
        .from('profiles')
        .select('points')
        .eq('id', userId)
        .single();

    int currentPoints = response['points'] ?? 0;
    int newPoints = currentPoints + points;

    await supabase
        .from('profiles')
        .update({'points': newPoints})
        .eq('id', userId);

    completedTasks.add(taskId);
    await prefs.setStringList('completedTasks', completedTasks);

  } catch (e) {
    print('Error updating points: $e');

    try {
      await supabase.from('profiles').upsert({
        'id': userId,
        'points': points,
        'updated_at': DateTime.now().toIso8601String()
      });

      completedTasks.add(taskId);
      await prefs.setStringList('completedTasks', completedTasks);

    } catch (innerError) {
      print('Error upserting profile: $innerError');
      throw innerError;
    }
  }
}

Future<bool> isTaskCompleted(String taskId) async {
  final prefs = await SharedPreferences.getInstance();
  final completedTasks = prefs.getStringList('completedTasks') ?? [];
  return completedTasks.contains(taskId);
}

final challengeDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, challengeId) async {
  final supabase = Supabase.instance.client;
  try {
    final data = await supabase
        .from('challenges')
        .select('*, tasks(*)')
        .eq('id', challengeId)
        .single();

    return data;
  } catch (e) {
    print('Error fetching challenge: $e');
    return null;
  }
});

final completedTasksProvider = StateProvider<List<String>>((ref) => []);

class ChallengeDetailPage extends ConsumerStatefulWidget {
  final String challengeId;

  const ChallengeDetailPage({
    Key? key,
    required this.challengeId,
  }) : super(key: key);

  @override
  _ChallengeDetailPageState createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends ConsumerState<ChallengeDetailPage> {
  List<String> completedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList('completedTasks') ?? [];
    setState(() {
      completedTasks = tasks;
    });
    ref.read(completedTasksProvider.notifier).state = tasks;
  }

  String formatEndTime(String? endTime) {
    if (endTime == null) return 'No end time specified';

    try {
      final DateTime dateTime = DateTime.parse(endTime);
      final DateFormat formatter = DateFormat('MMM dd, yyyy • hh:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return 'Invalid date format';
    }
  }

  @override
  Widget build(BuildContext context) {
    final challengeAsync = ref.watch(challengeDetailProvider(widget.challengeId));
    final completedTasksList = ref.watch(completedTasksProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'CHALLENGE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          // --- FORUM BUTTON FIXED HERE ---
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForumPage(challengeId: widget.challengeId),
                ),
              );
            },
            icon: Icon(Icons.forum, color: Colors.blue),
            label: Text(
              'Forum',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: challengeAsync.when(
        data: (challenge) {
          if (challenge == null) {
            return Center(
              child: Text(
                'CHALLENGE NOT FOUND',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            );
          }
          final tasks = challenge['tasks'] as List;
          final challengeName = challenge['name'] ?? 'UNTITLED';
          final endTime = challenge['end_time'];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challengeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        challenge['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.black12, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ENDS: ${formatEndTime(endTime)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                      height: 24,
                      width: 4,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'TASKS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (tasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        'NO TASKS AVAILABLE',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskId = task['id'].toString();
                      final isCompleted = completedTasksList.contains(taskId);
                      final points = task['points'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12, width: 1),
                          color: isCompleted
                              ? Colors.green.withOpacity(0.1)
                              : (index % 2 == 0 ? Colors.white : Colors.grey[50]),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isCompleted ? Colors.green : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isCompleted ? Colors.green : Colors.black,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: isCompleted ? Colors.green : Colors.black,
                                      width: 1
                                  ),
                                  color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.transparent,
                                ),
                                child: Text(
                                  '${points} PTS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isCompleted ? Colors.green : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                  color: isCompleted ? Colors.green : Colors.grey,
                                ),
                                onPressed: isCompleted ? null : () async {
                                  await completeTask(taskId, points);
                                  setState(() {
                                    completedTasks.add(taskId);
                                  });
                                  ref.read(completedTasksProvider.notifier).state = [...completedTasks];

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('You earned $points points!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'ERROR LOADING CHALLENGE',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}




