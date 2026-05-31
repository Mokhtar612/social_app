import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'user_profile_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _loadingFollowIds = {}; // Track loading states for buttons
  bool _currentUserIsAdmin = false;

  final List<String> _trendingTags = [
    '#Flutter',
    '#NodeJS',
    '#WebRTC',
    '#UXDesign',
    '#AIPlayground'
  ];
  String _selectedTag = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final apiService = context.read<ApiService>();
    final users = await apiService.fetchExploreUsers();
    final profile = await apiService.fetchProfile();
    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _currentUserIsAdmin = profile != null && profile['is_admin'] == true;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    _applyFilters(query, _selectedTag);
  }

  void _applyFilters(String query, String tag) {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final username = (user['username'] ?? '').toString().toLowerCase();
        final bio = (user['bio'] ?? '').toString().toLowerCase();
        
        bool matchesQuery = username.contains(query) || bio.contains(query);
        bool matchesTag = true;

        if (tag.isNotEmpty) {
          // Simulate tag filtering on bio content or username
          final tagText = tag.substring(1).toLowerCase();
          matchesTag = bio.contains(tagText) || username.contains(tagText);
        }

        return matchesQuery && matchesTag;
      }).toList();
    });
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    final userId = user['id'] as int;
    final isCurrentlyFollowing = user['is_following'] == true;

    setState(() => _loadingFollowIds.add(userId));

    final apiService = context.read<ApiService>();
    final newFollowState = await apiService.toggleFollow(userId, isCurrentlyFollowing);

    if (mounted) {
      setState(() {
        _loadingFollowIds.remove(userId);
        if (newFollowState != null) {
          user['is_following'] = newFollowState;
          // Sync changes back to the main list
          final index = _allUsers.indexWhere((u) => u['id'] == userId);
          if (index != -1) {
            _allUsers[index]['is_following'] = newFollowState;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

    return Scaffold(
      backgroundColor: kDarkBg,
      body: Column(
        children: [
          // ── Search & Trending Header (Glassmorphism static element) ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: kDarkSurface.withOpacity(0.85),
              border: const Border(
                bottom: BorderSide(color: kDarkBorder, width: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: kTextPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search creators, developers, bios...',
                    prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: kTextMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters('', _selectedTag);
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                // Trending tags label
                const Text(
                  'Trending Topics',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Tags Horizontal Scroll
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _trendingTags.length,
                    itemBuilder: (context, index) {
                      final tag = _trendingTags[index];
                      final isSelected = _selectedTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTag = isSelected ? '' : tag;
                            });
                            _applyFilters(_searchController.text, _selectedTag);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: isSelected ? kAccentGradient : null,
                              color: isSelected ? null : kDarkSurface2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? kAccent : kDarkBorder,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: isSelected ? kTextPrimary : kTextSecondary,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Users list (Scrollable, clean UI cards without backdrop filter overlay) ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: kAccent,
                    onRefresh: _fetchUsers,
                    child: _filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserCard(user, baseUrl);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, String baseUrl) {
    final userId = user['id'] as int;
    final isFollowing = user['is_following'] == true;
    final isBtnLoading = _loadingFollowIds.contains(userId);
    final bio = user['bio'] ?? 'No bio shared yet.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: userId),
                      ),
                    ).then((_) => _fetchUsers());
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Avatar
                      _buildAvatar(user, baseUrl),
                      const SizedBox(width: 14),
                      // User Meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user['username'] ?? 'User',
                                  style: const TextStyle(
                                    color: kTextPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (_currentUserIsAdmin) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (user['warnings_count'] ?? 0) > 0 ? kRed.withOpacity(0.15) : kTextMuted.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Warnings: ${user['warnings_count'] ?? 0}/3',
                                      style: TextStyle(
                                        color: (user['warnings_count'] ?? 0) > 0 ? kRed : kTextSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bio,
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Follow Button with loading state
              SizedBox(
                width: 96,
                height: 34,
                child: isBtnLoading
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: () => _toggleFollow(user),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isFollowing ? kDarkSurface2 : kAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isFollowing ? kDarkBorder : kAccent,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowing ? kTextSecondary : kTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (_currentUserIsAdmin) ...[
            const SizedBox(height: 10),
            const Divider(color: kDarkBorder, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Warn Button
                TextButton.icon(
                  onPressed: () => _warnUserConfirm(user),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                  label: const Text('Warn User', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                // Delete Button
                TextButton.icon(
                  onPressed: () => _deleteUserConfirm(user),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                  label: const Text('Delete User', style: TextStyle(color: kRed, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    backgroundColor: kRed.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _warnUserConfirm(Map<String, dynamic> user) async {
    final username = user['username'] ?? 'User';
    final currentWarnings = user['warnings_count'] ?? 0;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warn User'),
        content: Text('Are you sure you want to warn $username?\n\n'
            'Current warnings: $currentWarnings/3.\n'
            'Warning them a 3rd time will delete their account permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Warn', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final apiService = context.read<ApiService>();
      final result = await apiService.warnUser(user['id']);
      if (!mounted) return;
      if (result != null && result['success'] == true) {
        if (result['user_deleted'] == true) {
          setState(() {
            _allUsers.removeWhere((u) => u['id'] == user['id']);
            _filteredUsers.removeWhere((u) => u['id'] == user['id']);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'User reached 3 warnings and was deleted.'),
              duration: const Duration(seconds: 4),
              backgroundColor: kRed,
            ),
          );
        } else {
          setState(() {
            user['warnings_count'] = result['warnings_count'];
            final idx = _allUsers.indexWhere((u) => u['id'] == user['id']);
            if (idx != -1) {
              _allUsers[idx]['warnings_count'] = result['warnings_count'];
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning sent. User now has ${result['warnings_count']}/3 warnings.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to warn user.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteUserConfirm(Map<String, dynamic> user) async {
    final username = user['username'] ?? 'User';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text('Are you sure you want to permanently delete $username?\n\n'
            'This will delete all their posts, replies, and messages. This action cannot be undone.'),
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
      final apiService = context.read<ApiService>();
      final success = await apiService.deleteUser(user['id']);
      if (!mounted) return;
      if (success) {
        setState(() {
          _allUsers.removeWhere((u) => u['id'] == user['id']);
          _filteredUsers.removeWhere((u) => u['id'] == user['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete user.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildAvatar(Map<String, dynamic> user, String baseUrl) {
    if (user['avatar_url'] != null) {
      final avatarUrl = user['avatar_url'].toString().startsWith('http')
          ? user['avatar_url']
          : '$baseUrl${user['avatar_url']}';
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(
          avatarUrl,
          headers: const {'ngrok-skip-browser-warning': 'true'},
        ),
      );
    }
    final firstLetter = (user['username'] ?? 'U')[0].toUpperCase();
    return CircleAvatar(
      radius: 22,
      backgroundColor: kAccent.withOpacity(0.12),
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: kAccent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: kTextMuted),
              const SizedBox(height: 16),
              const Text(
                'No Creators Found',
                style: TextStyle(color: kTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedTag.isNotEmpty
                    ? 'Try changing tags or adjusting keywords'
                    : 'Check your search query and try again',
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
