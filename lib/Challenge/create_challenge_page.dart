import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Task {
  String name;
  int points;

  Task({required this.name, required this.points});
}

class CreateChallengePage extends StatefulWidget {
  @override
  _CreateChallengePageState createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  String challengeName = '';
  List<Task> tasks = [];
  bool _isLoading = false;
  DateTime? endTime;

  void _addTask() {
    setState(() {
      tasks.add(Task(name: '', points: 0));
    });
  }

  void _removeTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
  }

  Future<void> _saveChallenge() async {
    if (_formKey.currentState!.validate()) {
      if (endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select an end time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      try {
        final userId = _supabase.auth.currentUser?.id;

        final response = await _supabase
            .from('challenges')
            .insert({
          'name': challengeName,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'end_time': endTime!.toIso8601String(),
        })
            .select()
            .single();

        final challengeId = response['id'];

        final tasksToInsert = tasks.map((task) => {
          'name': task.name,
          'points': task.points,
          'challenge_id': challengeId,
          'user_id': userId,
        }).toList();

        await _supabase.from('tasks').insert(tasksToInsert);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge saved successfully!'),
            backgroundColor: Colors.black,
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving challenge: $error'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Create Challenge',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Challenge Name',
                  labelStyle: TextStyle(color: Colors.black54),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                ),
                cursorColor: Colors.black,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a challenge name';
                  }
                  return null;
                },
                onSaved: (value) {
                  challengeName = value!;
                },
              ),

              SizedBox(height: 24),
              Text(
                'End Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );

                    if (pickedTime != null) {
                      setState(() {
                        endTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        endTime == null
                            ? 'Select end time'
                            : '${endTime!.toLocal()}'.split('.')[0],
                        style: TextStyle(
                          color:
                          endTime == null ? Colors.black54 : Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      Icon(Icons.calendar_today, color: Colors.black54, size: 18),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TASKS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.black),
                    onPressed: _addTask,
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...tasks.asMap().entries.map((entry) {
                int index = entry.key;
                Task task = entry.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 20),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TASK ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: Colors.black54,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: Colors.black54),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () => _removeTask(index),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Task Name',
                          labelStyle: TextStyle(color: Colors.black54),
                          focusedBorder: UnderlineInputBorder(
                            borderSide:
                            BorderSide(color: Colors.black, width: 2),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black26),
                          ),
                        ),
                        cursorColor: Colors.black,
                        initialValue: task.name,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a task name';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          tasks[index].name = value!;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Points',
                          labelStyle: TextStyle(color: Colors.black54),
                          focusedBorder: UnderlineInputBorder(
                            borderSide:
                            BorderSide(color: Colors.black, width: 2),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black26),
                          ),
                        ),
                        cursorColor: Colors.black,
                        keyboardType: TextInputType.number,
                        initialValue: task.points.toString(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter points';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          tasks[index].points = int.parse(value!);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 32),
              if (tasks.isEmpty)
                Center(
                  child: Text(
                    'Add tasks to your challenge',
                    style: TextStyle(color: Colors.black38, fontSize: 16),
                  ),
                ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChallenge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'SAVE CHALLENGE',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




