import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'create_post_screen.dart';
import 'user_profile_screen.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<dynamic> _posts = [];
  bool _isLoading = true;
  int? _currentUserId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    setState(() => _isLoading = true);
    final apiService = context.read<ApiService>();
    final posts = await apiService.fetchFeed();
    final profile = await apiService.fetchProfile();
    final userId = profile?['id'];
    if (mounted) {
      setState(() {
        _posts   = posts;
        _currentUserId = userId;
        _isAdmin = profile != null && profile['is_admin'] == true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          if (result == true) _fetchFeed();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: kTextMuted),
            const SizedBox(height: 16),
            const Text(
              'No posts yet.',
              style: TextStyle(color: kTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Be the first to share something!',
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: kAccent,
      backgroundColor: kDarkSurface,
      onRefresh: _fetchFeed,
      child: ListView.builder(
        itemCount: _posts.length,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemBuilder: (_, i) => _buildPostCard(_posts[i]),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(userId: post['user_id']),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        _buildAvatar(post, baseUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['username'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: kTextPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatDate(post['created_at']),
                                style: const TextStyle(color: kTextMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: kTextMuted,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showPostOptionsMenu(context, post),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Content ─────────────────────────────────────────────
            if ((post['content'] ?? '').isNotEmpty) ...[
              Text(
                post['content'],
                style: const TextStyle(color: kTextPrimary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],

            // ── Image ───────────────────────────────────────────────
            if (post['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _resolveUrl(baseUrl, post['image_url']),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  headers: const {'ngrok-skip-browser-warning': 'true'},
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: kDarkSurface2,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: kTextMuted, size: 40),
                    ),
                  ),
                ),
              ),

            if (post['image_url'] != null) const SizedBox(height: 12),

            // ── Video ───────────────────────────────────────────────
            if (post['video_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PostVideoPlayer(url: _resolveUrl(baseUrl, post['video_url'])),
              ),

            if (post['video_url'] != null) const SizedBox(height: 12),

            // ── Footer / Like ────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _likePost(post['id'], _posts.indexOf(post)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      post['is_liked'] == true
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(post['is_liked']),
                      color: post['is_liked'] == true ? kRed : kTextMuted,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${post['likes_count'] ?? 0}',
                  style: const TextStyle(color: kTextSecondary, fontSize: 13),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _showRepliesBottomSheet(context, post),
                  behavior: HitTestBehavior.opaque,
                  child: const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: kTextMuted, size: 20),
                      SizedBox(width: 6),
                      Text('Reply', style: TextStyle(color: kTextMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> post, String baseUrl) {
    if (post['avatar_url'] != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(
          _resolveUrl(baseUrl, post['avatar_url']),
          headers: const {'ngrok-skip-browser-warning': 'true'},
        ),
      );
    }
    final letter = (post['username'] ?? '?')[0].toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: kAccent.withOpacity(0.2),
      child: Text(
        letter,
        style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }

  void _showRepliesBottomSheet(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostRepliesBottomSheet(post: post),
    );
  }

  void _showPostOptionsMenu(BuildContext context, Map<String, dynamic> post) {
    final isOwner = _currentUserId != null && post['user_id'] == _currentUserId;
    final canDelete = isOwner || _isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kDarkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                if ((post['content'] ?? '').toString().trim().isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded, color: kTextSecondary),
                    title: const Text('Copy Text', style: TextStyle(color: kTextPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: post['content']));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Text copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.visibility_off_rounded, color: kTextSecondary),
                  title: const Text('Hide Post', style: TextStyle(color: kTextPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _posts.removeWhere((p) => p['id'] == post['id']);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post hidden'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_gmailerrorred_rounded, color: kTextSecondary),
                  title: const Text('Report Post', style: TextStyle(color: kTextPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post reported'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                if (canDelete) ...[
                  const Divider(color: kDarkBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: kRed),
                    title: const Text('Delete Post', style: TextStyle(color: kRed)),
                    onTap: () {
                      Navigator.pop(context);
                      _deletePost(post['id']);
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final apiService = context.read<ApiService>();
      final success = await apiService.deletePost(postId);
      if (success) {
        setState(() {
          _posts.removeWhere((p) => p['id'] == postId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete post. Please try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _likePost(int postId, int index) async {
    final apiService = context.read<ApiService>();
    final result = await apiService.toggleLike(postId);
    if (result != null && mounted) {
      setState(() {
        _posts[index]['likes_count'] = result['likes_count'];
        _posts[index]['is_liked']    = result['is_liked'];
      });
    }
  }

  String _resolveUrl(String base, String? path) {
    if (path == null) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$base$path';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Video Player Widget (unchanged logic) ────────────────────────────────────
class PostVideoPlayer extends StatefulWidget {
  final String url;
  const PostVideoPlayer({super.key, required this.url});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {'ngrok-skip-browser-warning': 'true'},
    )..initialize().then((_) {
        setState(() {});
      }).catchError((_) {
        setState(() => _isError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Container(
        height: 200, color: kDarkSurface2,
        child: const Center(child: Icon(Icons.error_outline, color: kRed, size: 36)),
      );
    }
    if (!_controller.value.isInitialized) {
      return Container(
        height: 200, color: kDarkSurface2,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        if (!_controller.value.isPlaying)
          GestureDetector(
            onTap: () => setState(() => _controller.play()),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: kTextPrimary, size: 40),
            ),
          ),
        if (_controller.value.isPlaying)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _controller.pause()),
            ),
          ),
      ],
    );
  }
}

// ─── Post Replies Bottom Sheet Widget ─────────────────────────────────────────
class PostRepliesBottomSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostRepliesBottomSheet({super.key, required this.post});

  @override
  State<PostRepliesBottomSheet> createState() => _PostRepliesBottomSheetState();
}

class _PostRepliesBottomSheetState extends State<PostRepliesBottomSheet> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _replies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchReplies() async {
    final apiService = context.read<ApiService>();
    final replies = await apiService.fetchPostReplies(widget.post['id']);
    if (mounted) {
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    final apiService = context.read<ApiService>();
    _replyController.clear();

    final newReply = await apiService.createPostReply(widget.post['id'], content);
    if (newReply != null && mounted) {
      setState(() {
        _replies.add(newReply);
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';
    final mediaQuery = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: mediaQuery.size.height * 0.65,
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kDarkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          
          // Header (Static element - Glassmorphism style border/bg)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kDarkBorder, width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Replies',
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_replies.length} comments',
                  style: const TextStyle(color: kTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

          // Scrollable replies list (Clean, no glassmorphism)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _replies.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _replies.length,
                        itemBuilder: (context, index) {
                          final reply = _replies[index];
                          return _buildReplyTile(reply, baseUrl);
                        },
                      ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kDarkBorder, width: 0.8)),
              color: kDarkBg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: const TextStyle(color: kTextPrimary, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitReply(),
                    decoration: InputDecoration(
                      hintText: 'Add a reply...',
                      fillColor: kDarkSurface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: kAccent),
                  onPressed: _submitReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyTile(Map<String, dynamic> reply, String baseUrl) {
    final username = reply['username'] ?? 'User';
    final content = reply['content'] ?? '';
    final avatarUrl = reply['avatar_url'] != null
        ? (reply['avatar_url'].toString().startsWith('http')
            ? reply['avatar_url']
            : '$baseUrl${reply['avatar_url']}')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarUrl != null
              ? CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                    avatarUrl,
                    headers: const {'ngrok-skip-browser-warning': 'true'},
                  ),
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: kAccent.withOpacity(0.12),
                  child: Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 40, color: kTextMuted),
          const SizedBox(height: 12),
          const Text(
            'No replies yet',
            style: TextStyle(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Be the first to share your thoughts!',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
