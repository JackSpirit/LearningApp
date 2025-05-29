import 'package:flutter/material.dart';

class Comment {
  final String id;
  final String author;
  final String text;
  final List<Reply> replies;

  Comment({
    required this.id,
    required this.author,
    required this.text,
    List<Reply>? replies,
  }) : replies = replies ?? [];
}

class Reply {
  final String id;
  final String author;
  final String text;

  Reply({
    required this.id,
    required this.author,
    required this.text,
  });
}

class ForumPage extends StatefulWidget {
  final String challengeId;
  const ForumPage({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  List<Comment> comments = [];

  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  String? replyingToCommentId;

  @override
  void dispose() {
    _commentController.dispose();
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      comments.add(
        Comment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          author: 'You',
          text: _commentController.text.trim(),
        ),
      );
      _commentController.clear();
    });
  }

  void _addReply(String commentId) {
    final controller = _replyControllers[commentId];
    if (controller == null || controller.text.trim().isEmpty) return;
    setState(() {
      final comment = comments.firstWhere((c) => c.id == commentId);
      comment.replies.add(
        Reply(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          author: 'You',
          text: controller.text.trim(),
        ),
      );
      controller.clear();
      replyingToCommentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Forum',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                _replyControllers.putIfAbsent(comment.id, () => TextEditingController());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Text(
                              comment.author[0],
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.author,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  comment.text,
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setState(() {
                                replyingToCommentId = comment.id;
                              });
                            },
                            child: Text('Reply'),
                          ),
                        ],
                      ),
                      if (comment.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0, top: 4.0),
                          child: Column(
                            children: comment.replies.map((reply) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[100],
                                  child: Text(
                                    reply.author[0],
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                                title: Text(
                                  reply.author,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                subtitle: Text(
                                  reply.text,
                                  style: TextStyle(color: Colors.black87),
                                ),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                tileColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(horizontal: 0.0),
                              );
                            }).toList(),
                          ),
                        ),
                      if (replyingToCommentId == comment.id)
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0, top: 4.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyControllers[comment.id],
                                  style: TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    hintText: 'Write a reply...',
                                    hintStyle: TextStyle(color: Colors.grey[500]),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.send, color: Colors.black),
                                onPressed: () => _addReply(comment.id),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Divider(color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.black),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}











