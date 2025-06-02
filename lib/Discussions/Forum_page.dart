import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

const _backgroundColor = Colors.white;
const _onBackgroundColor = Colors.black;
const _cardColor = Colors.white;
const _onCardColor = Colors.black;
const _primaryColor = Colors.black;
const _secondaryTextColor = Colors.black54;
const _borderColor = Colors.black12;

class UserProfile {
  final String id;
  final String name;
  final String? avatarUrl;

  UserProfile({required this.id, required this.name, this.avatarUrl});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String? rawAvatarPathOrUrl = json['avatar'] as String?;
    String? finalAvatarUrl;

    if (rawAvatarPathOrUrl != null && rawAvatarPathOrUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawAvatarPathOrUrl);
      if (uri != null && uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https')) {
        finalAvatarUrl = rawAvatarPathOrUrl;
      } else {
        final String bucketName = 'avatar';
        final supabase = Supabase.instance.client;

        final path = rawAvatarPathOrUrl.startsWith('/')
            ? rawAvatarPathOrUrl.substring(1)
            : rawAvatarPathOrUrl;

        if (path.isNotEmpty) {
          finalAvatarUrl = supabase.storage.from(bucketName).getPublicUrl(path);
        } else {
        }
      }
    }

    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Anonymous',
      avatarUrl: finalAvatarUrl,
    );
  }
}

class ForumMessage {
  final int id;
  final String challengeId;
  final String userId;
  final String content;
  final int? parentId;
  final DateTime createdAt;
  final int upvotes;
  UserProfile? user;
  List<ForumMessage> replies;

  ForumMessage({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.content,
    this.parentId,
    required this.createdAt,
    required this.upvotes,
    this.user,
    this.replies = const [],
  });

  factory ForumMessage.fromJson(Map<String, dynamic> json) {
    UserProfile? authorProfile;
    if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      try {
        authorProfile = UserProfile.fromJson(json['profiles'] as Map<String, dynamic>);
      } catch (e) {
        print("Error creating UserProfile from profiles data: ${json['profiles']}. Error: $e");
      }
    }
    return ForumMessage(
      id: json['id'] as int,
      challengeId: json['challenge_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      parentId: json['parent_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      upvotes: json['upvotes'] as int? ?? 0,
      user: authorProfile,
      replies: [],
    );
  }
}

class ForumService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print("ForumService: No current user found.");
      return null;
    }
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, name, avatar')
          .eq('id', user.id)
          .single();
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching current user profile: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.message} (Code: ${e.code})');
      }
      return null;
    }
  }

  Future<List<ForumMessage>> fetchMessages(String challengeId) async {
    try {
      final response = await _supabase
          .from('forum_messages')
          .select('*, profiles!inner(id, name, avatar), upvotes')
          .eq('challenge_id', challengeId)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final List<ForumMessage> allMessages = data
          .map((item) {
        try {
          Map<String, dynamic> messageData = item as Map<String, dynamic>;
          if (messageData['profiles'] == null && item['user_id'] != null) {
            print("Warning: Profile data missing for message ID ${messageData['id']}, user ID ${messageData['user_id']}");
          }
          return ForumMessage.fromJson(messageData);
        } catch (e) {
          print("Error parsing ForumMessage from data: $item. Error: $e");
          rethrow;
        }
      })
          .toList();

      final Map<int?, List<ForumMessage>> messagesByParentId = {};
      for (var msg in allMessages) {
        messagesByParentId.putIfAbsent(msg.parentId, () => []).add(msg);
      }

      List<ForumMessage> buildThread(int? parentId) {
        List<ForumMessage> children = messagesByParentId[parentId] ?? [];
        for (var child in children) {
          child.replies = buildThread(child.id);
        }
        return children;
      }

      final List<ForumMessage> topLevelMessages = buildThread(null);
      return topLevelMessages;
    } catch (e) {
      print('Error fetching messages: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.message} (Code: ${e.code})');
      }
      throw Exception('Failed to load forum messages. Please check RLS policies and network.');
    }
  }


  Future<void> postMessage({
    required String challengeId,
    required String content,
    required String userId,
    int? parentId,
  }) async {
    try {
      final messageData = {
        'challenge_id': challengeId,
        'user_id': userId,
        'content': content,
        'parent_id': parentId,
      };
      await _supabase.from('forum_messages').insert(messageData);
    } catch (e) {
      print('Error posting message: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.message} (Code: ${e.code})');
      }
      throw Exception('Failed to post message. Please check RLS policies.');
    }
  }

  Future<void> upvoteMessage(int messageId) async {
    try {
      await _supabase.rpc(
        'increment_message_upvotes',
        params: {'message_id_to_inc': messageId},
      );
    } catch (e) {
      print('Error upvoting message $messageId: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.message} (Code: ${e.code})');
      }
      throw Exception('Failed to upvote message.');
    }
  }


  Future<String?> fetchChallengeName(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenges')
          .select('name')
          .eq('id', challengeId)
          .maybeSingle();

      if (response != null && response['name'] != null) {
        return response['name'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching challenge name for ID $challengeId: $e');
      return null;
    }
  }
  Future<void> updateUserFcmToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print("ForumService: No current user to update FCM token for.");
      return;
    }
    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
      print('FCM token updated for user ${user.id}');
    } catch (e) {
      print('Error updating FCM token: $e');
      if (e is PostgrestException) {
        print('PostgrestException details for FCM update: ${e.message} (Code: ${e.code})');
      }
    }
  }
}

class ForumPage extends StatefulWidget {
  final String challengeId;
  final String? messageIdToFocus;

  const ForumPage({super.key, required this.challengeId, this.messageIdToFocus});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final ForumService _forumService = ForumService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;


  Future<List<ForumMessage>>? _messagesFuture;
  UserProfile? _currentUserProfile;
  String? _challengeName;
  bool _isLoadingProfile = true;
  bool _isLoadingChallengeDetails = true;
  bool _isPosting = false;

  int? _replyingToMessageId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
      _firebaseMessaging.getToken().then((token) {
        if (token != null) {
          print("FCM Token: $token");
          _forumService.updateUserFcmToken(token);
        }
      });

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print("FCM Token Refreshed: $newToken");
        _forumService.updateUserFcmToken(newToken);
      });
    } else {
      print('User declined or has not accepted notification permission');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: _onBackgroundColor,
                content: Text(
                  'New reply: ${message.notification?.title ?? ''} - ${message.notification?.body ?? ''}',
                  style: const TextStyle(color: _backgroundColor),
                ),
                action: SnackBarAction(
                  label: 'View',
                  textColor: _backgroundColor,
                  onPressed: () {
                    _fetchMessages();
                  },
                ),
              )
          );
          _fetchMessages();
        }
      }
    });

   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened app from background:');
      _handleNotificationInteraction(message);
    });

    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Message opened app from terminated state:');
        _handleNotificationInteraction(message);
      }
    });
  }

  void _handleNotificationInteraction(RemoteMessage message) {
    print('Handling notification interaction: ${message.messageId}');
    print('Notification data: ${message.data}');
    _fetchMessages();

  }


  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _isLoadingChallengeDetails = true;
      _messagesFuture = null;
    });

    try {
      final results = await Future.wait([
        _forumService.getCurrentUserProfile(),
        _forumService.fetchChallengeName(widget.challengeId),
      ]);

      if (!mounted) return;

      _currentUserProfile = results[0] as UserProfile?;
      _challengeName = results[1] as String?;

    } catch (e) {
      print("Error loading initial page data (profile/challenge name): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading page details: ${e.toString()}', style: const TextStyle(color: _backgroundColor)),
            backgroundColor: _onBackgroundColor,
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _isLoadingChallengeDetails = false;
      });
    }

    if (_currentUserProfile == null && mounted && !_isLoadingProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load user profile. Posting disabled.', style: TextStyle(color: _backgroundColor)),
          backgroundColor: _onBackgroundColor,
        ),
      );
    }
    _fetchMessages();
  }

  void _fetchMessages() {
    if (!mounted) return;
    setState(() {
      _messagesFuture = _forumService.fetchMessages(widget.challengeId);
    });
  }

  Future<void> _handlePostMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_currentUserProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot post: User not identified.', style: TextStyle(color: _backgroundColor)),
          backgroundColor: _onBackgroundColor,
        ),
      );
      return;
    }
    if (_isPosting) return;

    setState(() { _isPosting = true; });

    try {
      await _forumService.postMessage(
        challengeId: widget.challengeId,
        content: _messageController.text.trim(),
        userId: _currentUserProfile!.id,
        parentId: _replyingToMessageId,
      );
      _messageController.clear();
      _messageFocusNode.unfocus();
      _cancelReply();
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting message: ${e.toString()}', style: const TextStyle(color: _backgroundColor)),
            backgroundColor: _onBackgroundColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isPosting = false; });
      }
    }
  }

  Future<void> _handleUpvoteMessage(int messageId) async {
    try {
      await _forumService.upvoteMessage(messageId);
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error upvoting message: ${e.toString()}', style: const TextStyle(color: _backgroundColor)),
            backgroundColor: _onBackgroundColor,
          ),
        );
      }
    }
  }

  void _startReply(ForumMessage message) {
    setState(() {
      _replyingToMessageId = message.id;
      _replyingToUsername = message.user?.name ?? 'User';
      _messageFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToUsername = null;
      _messageController.clear();
      _messageFocusNode.unfocus();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    if (_isLoadingChallengeDetails) {
      appBarTitle = 'Forum: Loading...';
    } else if (_challengeName != null && _challengeName!.isNotEmpty) {
      appBarTitle = 'Forum: $_challengeName';
    } else {
      appBarTitle = 'Forum: Challenge ${widget.challengeId.length > 6 ? widget.challengeId.substring(0,6) : widget.challengeId}...';
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: _onBackgroundColor, fontWeight: FontWeight.normal)),
        backgroundColor: _backgroundColor,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _onBackgroundColor),
        actionsIconTheme: const IconThemeData(color: _onBackgroundColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingProfile || _isLoadingChallengeDetails || _isPosting ? null : _loadInitialData,
            tooltip: "Refresh Forum",
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: (_isLoadingProfile || _isLoadingChallengeDetails) && _messagesFuture == null
                ? const Center(child: CircularProgressIndicator(color: _onBackgroundColor, semanticsLabel: "Loading forum data..."))
                : _buildMessagesList(),
          ),
          if (_currentUserProfile != null) _buildMessageInputArea(),
          if (_currentUserProfile == null && !_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                  "Login required to post messages.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _secondaryTextColor)
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if ((_isLoadingProfile || _isLoadingChallengeDetails) && _messagesFuture == null) {
      return const Center(child: CircularProgressIndicator(color: _onBackgroundColor));
    }
    if (_messagesFuture == null) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                _isLoadingChallengeDetails || _isLoadingProfile
                    ? 'Loading page details...'
                    : 'Could not load messages. Please try refreshing.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _secondaryTextColor)),
          ));
    }

    return FutureBuilder<List<ForumMessage>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && (_isLoadingProfile || _isLoadingChallengeDetails || snapshot.data == null) ) {
          return const Center(child: CircularProgressIndicator(color: _onBackgroundColor));
        }
        if (snapshot.hasError) {
          print("FutureBuilder error: ${snapshot.error}");
          print("FutureBuilder stackTrace: ${snapshot.stackTrace}");
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading messages: ${snapshot.error}\n\nPlease ensure RLS policies are correctly configured and you have network connectivity.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _secondaryTextColor)),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('No messages yet. Be the first to post!',
                  style: TextStyle(color: _secondaryTextColor)));
        }

        final messages = snapshot.data!;
        // TODO: Implement scroll to widget.messageIdToFocus if provided
        return RefreshIndicator(
          color: _onBackgroundColor,
          backgroundColor: _backgroundColor,
          onRefresh: () async => _loadInitialData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _MessageItem(
                key: ValueKey(message.id),
                message: message,
                onReply: _startReply,
                onUpvote: _handleUpvoteMessage,
                depth: 0,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessageInputArea() {
    return Material(
      color: _backgroundColor,
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 8.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 8.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyingToMessageId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Text(
                      'Replying to ${_replyingToUsername ?? 'message'}',
                      style: const TextStyle(color: _secondaryTextColor, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: _secondaryTextColor),
                      onPressed: _cancelReply,
                      tooltip: "Cancel Reply",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    style: const TextStyle(color: _onBackgroundColor),
                    decoration: InputDecoration(
                      hintText: _replyingToMessageId != null ? 'Write your reply...' : 'Type a message...',
                      hintStyle: const TextStyle(color: _secondaryTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.03),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handlePostMessage(),
                    enabled: !_isPosting,
                  ),
                ),
                const SizedBox(width: 8),
                _isPosting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _onBackgroundColor))
                    : IconButton(
                  icon: const Icon(Icons.send, color: _primaryColor),
                  onPressed: _isPosting ? null : _handlePostMessage,
                  tooltip: "Send Message",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  final ForumMessage message;
  final Function(ForumMessage) onReply;
  final Function(int messageId) onUpvote;
  final int depth;

  const _MessageItem({
    super.key,
    required this.message,
    required this.onReply,
    required this.onUpvote,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final user = message.user;
    final double indentPadding = depth * 20.0;

    return Card(
      color: _cardColor,
      elevation: depth == 0 ? 0.5 : 0.2,
      margin: EdgeInsets.only(left: indentPadding, top: 4.0, bottom: 4.0, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: depth == 0 ? const BorderSide(color: _borderColor, width: 0.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  foregroundColor: _onBackgroundColor,
                  backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  onBackgroundImageError: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) ? (exception, stackTrace) {
                    print("Error loading avatar for ${user?.name} (URL: ${user?.avatarUrl}): $exception");
                  } : null,
                  child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                      ? Text(
                      (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 16, color: _onBackgroundColor))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Anonymous User',
                        style: const TextStyle(color: _onCardColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        _formatDateTime(message.createdAt),
                        style: const TextStyle(color: _secondaryTextColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message.content, style: const TextStyle(color: _onCardColor, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18, color: _primaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onUpvote(message.id),
                  tooltip: 'Upvote this message',
                ),
                const SizedBox(width: 4),
                Text(
                  '${message.upvotes}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('REPLY', style: TextStyle(fontSize: 12)),
                  onPressed: () => onReply(message),
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            if (message.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: message.replies
                      .map((reply) => _MessageItem(
                    key: ValueKey(reply.id),
                    message: reply,
                    onReply: onReply,
                    onUpvote: onUpvote,
                    depth: depth + 1,
                  ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays >= 7) {
      final year = dt.year.toString().substring(2);
      return '${dt.day}/${dt.month}/$year';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inSeconds > 10) {
      return '${difference.inSeconds}s ago';
    }
    else {
      return 'Just now';
    }
  }
}



























