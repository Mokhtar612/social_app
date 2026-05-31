import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'feed_tab.dart'; // To reuse PostRepliesBottomSheet
import 'user_profile_screen.dart';

class VideoTab extends StatefulWidget {
  const VideoTab({super.key});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  List<dynamic> _videoPosts = [];
  bool _isLoading = true;
  int? _currentUserId;
  bool _currentUserIsAdmin = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchVideoFeed();
  }

  Future<void> _fetchVideoFeed() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final apiService = context.read<ApiService>();
    final allPosts = await apiService.fetchFeed();
    final profile = await apiService.fetchProfile();
    final userId = profile?['id'];
    
    // Filter posts to only those containing a video
    final videoPosts = allPosts.where((p) => p['video_url'] != null && (p['video_url'] as String).isNotEmpty).toList();

    if (mounted) {
      setState(() {
        _videoPosts = videoPosts;
        _currentUserId = userId;
        _currentUserIsAdmin = profile != null && profile['is_admin'] == true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kDarkBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_videoPosts.isEmpty) {
      return Scaffold(
        backgroundColor: kDarkBg,
        body: RefreshIndicator(
          color: kAccent,
          backgroundColor: kDarkSurface,
          onRefresh: _fetchVideoFeed,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_outlined, size: 56, color: kTextMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No videos yet.',
                      style: TextStyle(color: kTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pull down to refresh or check back later!',
                      style: TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: kAccent,
        backgroundColor: kDarkSurface,
        onRefresh: _fetchVideoFeed,
        notificationPredicate: (notification) => notification.depth == 1, // trigger refresh on listview / pages
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: _videoPosts.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final post = _videoPosts[index];
            return VideoSwipeItem(
              post: post,
              isActive: index == _currentPage,
              currentUserId: _currentUserId,
              currentUserIsAdmin: _currentUserIsAdmin,
              onDelete: (postId) {
                setState(() {
                  _videoPosts.removeWhere((p) => p['id'] == postId);
                });
              },
              onHide: (postId) {
                setState(() {
                  _videoPosts.removeWhere((p) => p['id'] == postId);
                });
              },
            );
          },
        ),
      ),
    );
  }
}

class VideoSwipeItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final int? currentUserId;
  final bool currentUserIsAdmin;
  final Function(int) onDelete;
  final Function(int) onHide;

  const VideoSwipeItem({
    super.key,
    required this.post,
    required this.isActive,
    required this.currentUserId,
    required this.currentUserIsAdmin,
    required this.onDelete,
    required this.onHide,
  });

  @override
  State<VideoSwipeItem> createState() => _VideoSwipeItemState();
}

class _VideoSwipeItemState extends State<VideoSwipeItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isError = false;
  bool _isPlaying = false;
  late Map<String, dynamic> _postState;

  @override
  void initState() {
    super.initState();
    _postState = Map<String, dynamic>.from(widget.post);
    _initializeVideo();
  }

  void _initializeVideo() {
    final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';
    final videoPath = _postState['video_url'];
    final videoUrl = videoPath.startsWith('http') ? videoPath : '$baseUrl$videoPath';

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: const {'ngrok-skip-browser-warning': 'true'},
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          if (widget.isActive) {
            _controller.play();
            _controller.setLooping(true);
            setState(() => _isPlaying = true);
          }
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _isError = true);
        }
      });
  }

  @override
  void didUpdateWidget(VideoSwipeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isActive && !oldWidget.isActive) {
        _controller.play();
        _controller.setLooping(true);
        setState(() => _isPlaying = true);
      } else if (!widget.isActive && oldWidget.isActive) {
        _controller.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _toggleLike() async {
    final apiService = context.read<ApiService>();
    final result = await apiService.toggleLike(_postState['id']);
    if (result != null && mounted) {
      setState(() {
        _postState['likes_count'] = result['likes_count'];
        _postState['is_liked'] = result['is_liked'];
      });
    }
  }

  void _showReplies(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostRepliesBottomSheet(post: _postState),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final isOwner = widget.currentUserId != null && _postState['user_id'] == widget.currentUserId;
    final canDelete = isOwner || widget.currentUserIsAdmin;

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
                if ((_postState['content'] ?? '').toString().trim().isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded, color: kTextSecondary),
                    title: const Text('Copy Text', style: TextStyle(color: kTextPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: _postState['content']));
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
                    widget.onHide(_postState['id']);
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
                      _deletePostConfirm(context);
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

  Future<void> _deletePostConfirm(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await apiService.deletePost(_postState['id']);
      if (!mounted) return;
      if (success) {
        widget.onDelete(_postState['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete post. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

    return Stack(
      children: [
        // 1. Video Player (Centered, covering the screen)
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: _buildVideoDisplay(),
          ),
        ),

        // 2. Play / Pause Indicator overlay
        if (_isInitialized && !_isPlaying)
          Center(
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
              ),
            ),
          ),

        // 3. Right-side interactive action buttons
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              // User Avatar
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: _postState['user_id']),
                    ),
                  );
                },
                child: _buildAvatarOverlay(baseUrl),
              ),
              const SizedBox(height: 24),

              // Like Button
              _buildActionButton(
                icon: _postState['is_liked'] == true
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _postState['is_liked'] == true ? kRed : Colors.white,
                label: '${_postState['likes_count'] ?? 0}',
                onTap: _toggleLike,
              ),
              const SizedBox(height: 18),

              // Comment Button
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                label: 'Reply',
                onTap: () => _showReplies(context),
              ),
              const SizedBox(height: 18),

              // More Options Button
              _buildActionButton(
                icon: Icons.more_horiz_rounded,
                color: Colors.white,
                label: 'More',
                onTap: () => _showOptionsMenu(context),
              ),
            ],
          ),
        ),

        // 4. Bottom-left post description overlay
        Positioned(
          left: 16,
          bottom: 30,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: _postState['user_id']),
                    ),
                  );
                },
                child: Text(
                  '@${_postState['username'] ?? 'unknown'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if ((_postState['content'] ?? '').isNotEmpty)
                Text(
                  _postState['content'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoDisplay() {
    if (_isError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: kTextMuted, size: 50),
            SizedBox(height: 10),
            Text('Error loading video', style: TextStyle(color: kTextSecondary)),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildAvatarOverlay(String baseUrl) {
    Widget avatarWidget;
    if (_postState['avatar_url'] != null) {
      final avatarPath = _postState['avatar_url'].toString();
      final avatarUrl = avatarPath.startsWith('http') ? avatarPath : '$baseUrl$avatarPath';
      avatarWidget = CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(
          avatarUrl,
          headers: const {'ngrok-skip-browser-warning': 'true'},
        ),
      );
    } else {
      final letter = (_postState['username'] ?? '?')[0].toUpperCase();
      avatarWidget = CircleAvatar(
        radius: 20,
        backgroundColor: kAccent,
        child: Text(
          letter,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: avatarWidget,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
