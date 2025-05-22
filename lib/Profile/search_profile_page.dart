import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:learning_app/Profile/display_profile_page.dart';

class ProfileSearchPage extends StatefulWidget {
  const ProfileSearchPage({Key? key}) : super(key: key);

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _searchProfiles(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        final response = await supabase
            .from('profiles')
            .select('id, name, avatar_url')
            .ilike('name', '%$query%')
            .limit(20);

        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error searching profiles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'SEARCH',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.0),
                borderRadius: BorderRadius.circular(0),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'FIND USERS',
                  hintStyle: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  prefixIcon: Icon(Icons.search, color: Colors.black, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.black, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                      });
                    },
                  )
                      : null,
                ),
                onChanged: (value) {
                  _searchProfiles(value);
                },
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
                cursorColor: Colors.black,
              ),
            ),
          ),

          Container(
            height: 1,
            color: Colors.black12,
            margin: EdgeInsets.symmetric(horizontal: 16),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ),
            )
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'NO USERS FOUND',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            )
          // Search results
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final profile = _searchResults[index];
                  return Column(
                    children: [
                      Container(
                        color: index % 2 == 0 ? Colors.white : Colors.grey[100],
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 1),
                              image: profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty
                                  ? DecorationImage(
                                image: NetworkImage(profile['avatar_url']),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: profile['avatar_url'] == null || profile['avatar_url'].toString().isEmpty
                                ? Center(
                              child: Text(
                                profile['name'] != null && profile['name'].toString().isNotEmpty
                                    ? profile['name'][0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900
                                ),
                              ),
                            )
                                : null,
                          ),
                          title: Text(
                            profile['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, color: Colors.black, size: 14),
                          onTap: () {
                           Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewProfilePage(userId: profile['id']),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}




