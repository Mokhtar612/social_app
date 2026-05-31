import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'feed_tab.dart'; // To reuse PostVideoPlayer and PostRepliesBottomSheet
import 'profile_screen.dart'; // To navigate to Edit Profile if it's own profile

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _posts = [];
  bool _isLoading = true;
  int? _currentUserId;
  bool _isLoggedInUserAdmin = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final apiService = context.read<ApiService>();
    
    // Fetch logged-in user profile
    final currentUserProfile = await apiService.fetchProfile();
    _currentUserId = currentUserProfile?['id'];
    _isLoggedInUserAdmin = currentUserProfile != null && currentUserProfile['is_admin'] == true;

    // Fetch target user profile and posts
    final profile = await apiService.fetchUserProfile(widget.userId);
    final posts = await apiService.fetchUserPosts(widget.userId);

    if (mounted) {
      setState(() {
        _profile = profile;
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isFollowLoading) return;
    setState(() => _isFollowLoading = true);

    final apiService = context.read<ApiService>();
    final isFollowing = _profile!['is_following'] == true;
    final targetId = _profile!['id'] as int;

    final newState = await apiService.toggleFollow(targetId, isFollowing);
    if (newState != null && mounted) {
      setState(() {
        _profile!['is_following'] = newState;
        // Adjust follower count locally
        if (newState) {
          _profile!['followers_count'] = (_profile!['followers_count'] ?? 0) + 1;
        } else {
          _profile!['followers_count'] = (_profile!['followers_count'] ?? 0) - 1;
        }
        _isFollowLoading = false;
      });
    } else {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: Text(_profile != null ? '@${_profile!['username']}' : 'Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(
                  child: Text('User profile not found.', style: TextStyle(color: kTextSecondary)),
                )
              : RefreshIndicator(
                  color: kAccent,
                  backgroundColor: kDarkSurface,
                  onRefresh: _loadAll,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Profile Header Info
                      SliverToBoxAdapter(
                        child: _buildHeader(_profile!, baseUrl),
                      ),
                      
                      // Title for posts section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_on_rounded, size: 16, color: kTextSecondary),
                              const SizedBox(width: 8),
                              Text(
                                'Posts (${_posts.length})',
                                style: const TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // User Posts Feed
                      _posts.isEmpty
                          ? SliverToBoxAdapter(
                              child: Container(
                                height: 180,
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 40, color: kTextMuted),
                                    SizedBox(height: 12),
                                    Text(
                                      'No posts shared yet.',
                                      style: TextStyle(color: kTextMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final post = _posts[index];
                                    return _buildPostCard(post, baseUrl);
                                  },
                                  childCount: _posts.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> user, String baseUrl) {
    final isMe = _currentUserId != null && user['id'] == _currentUserId;
    final isFollowing = user['is_following'] == true;
    final bio = user['bio'] ?? 'No bio shared yet.';
    final warnings = user['warnings_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: kDarkSurface,
        border: Border(bottom: BorderSide(color: kDarkBorder, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              _buildAvatar(user, baseUrl),
              const SizedBox(width: 24),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Posts', '${user['posts_count'] ?? 0}'),
                    _buildStatCol('Followers', '${user['followers_count'] ?? 0}'),
                    _buildStatCol('Following', '${user['following_count'] ?? 0}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Username & Warnings Badge
          Row(
            children: [
              Text(
                user['username'] ?? 'User',
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoggedInUserAdmin && warnings > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Warnings: $warnings/3',
                    style: const TextStyle(color: kRed, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Bio
          Text(
            bio,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Action Button (Follow/Unfollow or Edit Profile)
          SizedBox(
            width: double.infinity,
            height: 40,
            child: isMe
                ? OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                      _loadAll(); // Reload profile after edit
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kDarkBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Edit Profile', style: TextStyle(color: kTextPrimary)),
                  )
                : ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? kDarkSurface2 : kAccent,
                      foregroundColor: isFollowing ? kTextSecondary : kTextPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isFollowing ? kDarkBorder : kAccent,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _isFollowLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> user, String baseUrl) {
    if (user['avatar_url'] != null) {
      final avatarUrl = user['avatar_url'].toString().startsWith('http')
          ? user['avatar_url']
          : '$baseUrl${user['avatar_url']}';
      return CircleAvatar(
        radius: 38,
        backgroundImage: NetworkImage(
          avatarUrl,
          headers: const {'ngrok-skip-browser-warning': 'true'},
        ),
      );
    }
    final firstLetter = (user['username'] ?? 'U')[0].toUpperCase();
    return CircleAvatar(
      radius: 38,
      backgroundColor: kAccent.withOpacity(0.12),
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: kAccent,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: kTextMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, String baseUrl) {
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
            // Header
            Row(
              children: [
                _buildCardAvatar(post, baseUrl),
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
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: kTextMuted,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showPostOptionsMenu(post),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content
            if ((post['content'] ?? '').isNotEmpty) ...[
              Text(
                post['content'],
                style: const TextStyle(color: kTextPrimary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],

            // Image
            if (post['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post['image_url'].toString().startsWith('http') ? post['image_url'] : '$baseUrl${post['image_url']}',
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

            // Video
            if (post['video_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PostVideoPlayer(
                  url: post['video_url'].toString().startsWith('http') ? post['video_url'] : '$baseUrl${post['video_url']}',
                ),
              ),

            if (post['video_url'] != null) const SizedBox(height: 12),

            // Footer
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _likePost(post['id'], _posts.indexOf(post)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      post['is_liked'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                  onTap: () => _showReplies(post),
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

  Widget _buildCardAvatar(Map<String, dynamic> post, String baseUrl) {
    if (post['avatar_url'] != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(
          post['avatar_url'].toString().startsWith('http') ? post['avatar_url'] : '$baseUrl${post['avatar_url']}',
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

  void _showReplies(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostRepliesBottomSheet(post: post),
    );
  }

  Future<void> _likePost(int postId, int index) async {
    final apiService = context.read<ApiService>();
    final result = await apiService.toggleLike(postId);
    if (result != null && mounted) {
      setState(() {
        _posts[index]['likes_count'] = result['likes_count'];
        _posts[index]['is_liked'] = result['is_liked'];
      });
    }
  }

  void _showPostOptionsMenu(Map<String, dynamic> post) {
    final isOwner = _currentUserId != null && post['user_id'] == _currentUserId;
    final canDelete = isOwner || _isLoggedInUserAdmin;

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

    if (confirm == true && mounted) {
      final apiService = context.read<ApiService>();
      final success = await apiService.deletePost(postId);
      if (!mounted) return;
      if (success) {
        setState(() {
          _posts.removeWhere((p) => p['id'] == postId);
        });
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
