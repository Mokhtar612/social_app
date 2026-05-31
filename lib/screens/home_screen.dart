import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'auth_screen.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';
import 'profile_screen.dart';
import 'public_chat_tab.dart';
import 'feed_tab.dart';
import 'explore_tab.dart';
import 'video_tab.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;

  int _unreadMessagesCount = 0;
  bool _showNotificationBanner = false;
  Map<String, dynamic>? _lastNotificationMessage;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final apiService = context.read<ApiService>();
    final wsService  = context.read<WebSocketService>();
    final profile    = await apiService.fetchProfile();
    if (!mounted) return;

    if (profile != null) {
      setState(() => _user = profile);
      wsService.connect();
      await Future.delayed(const Duration(milliseconds: 500));
      wsService.register(profile['id']);
    }
    wsService.addMessageListener(_handleIncomingCall);
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (data['type'] == 'call_request') {
      _showIncomingCallDialog(data['payload']);
    } else if (data['type'] == 'call_accepted') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            targetUserId: data['payload']['target_user_id'],
            isCaller: true,
          ),
        ),
      );
    } else if (data['type'] == 'chat_message') {
      _handleIncomingChatMessage(data['payload']);
    }
  }

  void _handleIncomingChatMessage(Map<String, dynamic> payload) {
    final senderId = payload['user_id'] as int;
    if (_user == null || senderId == _user!['id']) return;

    if (_currentIndex != 0) {
      setState(() {
        _unreadMessagesCount++;
        _lastNotificationMessage = payload;
        _showNotificationBanner = true;
      });

      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showNotificationBanner = false;
          });
        }
      });
    }
  }

  void _showIncomingCallDialog(Map<String, dynamic> payload) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('User ${payload['sender_user_id']} is calling you.'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<WebSocketService>().send('call_declined', {
                'target_user_id': payload['sender_user_id'],
                'sender_user_id': _user?['id'],
              });
              Navigator.pop(ctx);
            },
            child: const Text('Reject', style: TextStyle(color: kRed)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<WebSocketService>().send('call_accepted', {
                'target_user_id': payload['sender_user_id'],
                'sender_user_id': _user?['id'],
              });
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    targetUserId: payload['sender_user_id'],
                    isCaller: false,
                  ),
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    final apiService = context.read<ApiService>();
    final wsService  = context.read<WebSocketService>();
    wsService.removeMessageListener(_handleIncomingCall);
    wsService.disconnect();
    await apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  void dispose() {
    context.read<WebSocketService>().removeMessageListener(_handleIncomingCall);
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

    final List<Widget> tabs = [
      const PublicChatTab(),
      const ExploreTab(),
      const VideoTab(),
      const FeedTab(),
    ];

    final titles = ['Public Group', 'Explore', 'Videos', 'Social Feed'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          // Group call button
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: kAccent),
            onPressed: () {
              if (_user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupCallScreen(currentUserId: _user!['id']),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loading user data...')),
                );
              }
            },
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: kTextMuted, size: 20),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _user != null && _user!['avatar_url'] != null
                  ? Hero(
                      tag: 'profile_avatar',
                      child: CircleAvatar(
                        radius: 17,
                        backgroundImage:
                            NetworkImage('$baseUrl${_user!['avatar_url']}'),
                      ),
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kDarkSurface2,
                        shape: BoxShape.circle,
                        border: Border.all(color: kDarkBorder),
                      ),
                      child: const Icon(Icons.person_outline, size: 18, color: kTextSecondary),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: tabs[_currentIndex],
            ),
          ),
          // In-App Notification Banner
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            top: _showNotificationBanner ? MediaQuery.of(context).padding.top + 10 : -100.0,
            left: 14,
            right: 14,
            child: _buildNotificationBanner(baseUrl),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDarkBorder, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() {
              _currentIndex = i;
              if (i == 0) {
                _unreadMessagesCount = 0;
                _showNotificationBanner = false;
              }
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Badge(
                label: _unreadMessagesCount > 0 ? Text('$_unreadMessagesCount') : null,
                isLabelVisible: _unreadMessagesCount > 0,
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              activeIcon: Badge(
                label: _unreadMessagesCount > 0 ? Text('$_unreadMessagesCount') : null,
                isLabelVisible: _unreadMessagesCount > 0,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Explore',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline_rounded),
              activeIcon: Icon(Icons.play_circle_fill_rounded),
              label: 'Videos',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined),
              activeIcon: Icon(Icons.photo_library_rounded),
              label: 'Feed',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBanner(String baseUrl) {
    if (_lastNotificationMessage == null) return const SizedBox.shrink();

    final username = _lastNotificationMessage!['username'] ?? 'User';
    final text = _lastNotificationMessage!['message_text'] ?? '';
    final hasAudio = _lastNotificationMessage!['audio_url'] != null &&
        (_lastNotificationMessage!['audio_url'] as String).isNotEmpty;
    final avatarUrl = _lastNotificationMessage!['avatar_url'] != null
        ? '$baseUrl${_lastNotificationMessage!['avatar_url']}'
        : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 0;
          _unreadMessagesCount = 0;
          _showNotificationBanner = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kDarkSurface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kAccent.withOpacity(0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: kAccent.withOpacity(0.12),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            avatarUrl != null
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      avatarUrl,
                      headers: const {'ngrok-skip-browser-warning': 'true'},
                    ),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: kAccent.withOpacity(0.15),
                    child: Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasAudio ? '🎤 Voice note' : text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: kAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
