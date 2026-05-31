import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../theme.dart';
import 'user_profile_screen.dart';

class PublicChatTab extends StatefulWidget {
  const PublicChatTab({super.key});

  @override
  State<PublicChatTab> createState() => _PublicChatTabState();
}

class _PublicChatTabState extends State<PublicChatTab> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController    = ScrollController();

  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? _user;

  final _audioRecorder = AudioRecorder();
  final _audioPlayer   = AudioPlayer();
  bool _isRecording       = false;
  String? _playingMessageId;
  Map<String, dynamic>? _replyMessage;
  late WebSocketService _wsService;

  @override
  void initState() {
    super.initState();
    _wsService = context.read<WebSocketService>();
    _init();
  }

  Future<void> _init() async {
    final apiService = context.read<ApiService>();

    final profile = await apiService.fetchProfile();
    if (!mounted) return;
    if (profile != null) setState(() => _user = profile);

    final history = await apiService.fetchChatHistory();
    if (!mounted) return;
    setState(() => messages = List<Map<String, dynamic>>.from(history));
    _scrollToBottom();

    _wsService.addMessageListener(_onMessage);
  }

  void _onMessage(Map<String, dynamic> data) {
    if (data['type'] == 'chat_message') {
      setState(() => messages.add(Map<String, dynamic>.from(data['payload'])));
      _scrollToBottom();
    } else if (data['type'] == 'message_deleted') {
      setState(() => messages.removeWhere((m) => m['id'] == data['payload']['message_id']));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty || _user == null) return;
    context.read<WebSocketService>().sendChatMessage(
      _user!['id'], 
      _textController.text.trim(),
      replyToId: _replyMessage?['id'],
    );
    _textController.clear();
    setState(() {
      _replyMessage = null;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir  = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null && _user != null) {
        final audioUrl = await context.read<ApiService>().uploadAudio(path);
        if (audioUrl != null) {
          context.read<WebSocketService>().sendChatMessage(
            _user!['id'], 
            '', 
            audioUrl: audioUrl,
            replyToId: _replyMessage?['id'],
          );
          setState(() {
            _replyMessage = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playAudio(Map<String, dynamic> item) async {
    try {
      final itemId  = item['id']?.toString() ?? '';
      final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

      if (_playingMessageId == itemId) {
        await _audioPlayer.stop();
        setState(() => _playingMessageId = null);
        return;
      }
      await _audioPlayer.stop();

      String audioUrl = item['audio_url'];
      if (audioUrl.startsWith('/'))  audioUrl = '$baseUrl$audioUrl';
      else if (!audioUrl.startsWith('http')) audioUrl = '$baseUrl/$audioUrl';

      setState(() => _playingMessageId = itemId);

      final dir       = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/audio_$itemId.m4a';
      final file      = File(localPath);

      if (!await file.exists()) {
        final response = await http.get(
          Uri.parse(audioUrl),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          setState(() => _playingMessageId = null);
          return;
        }
      }
      await _audioPlayer.play(DeviceFileSource(localPath));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingMessageId = null);
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() => _playingMessageId = null);
    }
  }

  @override
  void dispose() {
    _wsService.removeMessageListener(_onMessage);
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Message Bubble ─────────────────────────────────────────────────────────
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe    = _user != null && msg['user_id'] == _user!['id'];
    final hasAudio = msg['audio_url'] != null && (msg['audio_url'] as String).isNotEmpty;
    final baseUrl  = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';
    final msgId    = msg['id']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: msg['user_id']),
                  ),
                );
              },
              child: msg['avatar_url'] != null
                  ? CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage('$baseUrl${msg['avatar_url']}'),
                    )
                  : CircleAvatar(
                      radius: 14,
                      backgroundColor: kAccent.withOpacity(0.2),
                      child: Text(
                        (msg['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageMenu(context, msg, isMe, hasAudio),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.73,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? kAccent : kDarkSurface2,
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(18),
                    topRight:    const Radius.circular(18),
                    bottomLeft:  Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg['reply_to_id'] != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isMe ? Colors.white : kAccent).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe ? Colors.white70 : kAccent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['reply_username'] ?? 'User',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white : kAccent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg['reply_text'] ?? (msg['audio_url'] != null ? 'Voice note' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!isMe) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            msg['username'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _startVideoCall(msg['user_id'], msg['username'] ?? 'User'),
                            child: const Icon(Icons.videocam_rounded, size: 15, color: kAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (hasAudio)
                      _buildAudioBubble(msg, isMe, msgId)
                    else
                      Text(
                        msg['message_text'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isMe ? kTextPrimary : kTextPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBubble(Map<String, dynamic> msg, bool isMe, String msgId) {
    final isPlaying = _playingMessageId == msgId;
    return GestureDetector(
      onTap: () => _playAudio(msg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
            size: 30,
            color: isMe ? kTextPrimary : kAccent,
          ),
          const SizedBox(width: 8),
          Row(
            children: [8.0, 14.0, 6.0, 12.0, 9.0].map((h) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 3,
                height: isPlaying ? h * 1.4 : h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isMe ? kTextPrimary.withOpacity(0.8) : kAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
          Text(
            isPlaying ? 'Playing…' : 'Voice',
            style: TextStyle(
              fontSize: 12,
              color: isMe ? kTextPrimary.withOpacity(0.8) : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
  void _showMessageMenu(BuildContext ctx, Map<String, dynamic> msg, bool isMe, bool hasAudio) {
    final isAdmin = _user != null && _user!['is_admin'] == true;
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: kDarkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyMessage = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: msg['user_id']),
                  ),
                );
              },
            ),
            if (!hasAudio)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg['message_text']));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            if (isMe || isAdmin)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: kRed),
                title: const Text('Delete', style: TextStyle(color: kRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<WebSocketService>().send('delete_message', {'message_id': msg['id']});
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startVideoCall(int targetUserId, String targetUsername) {
    context.read<WebSocketService>().send('call_request', {
      'target_user_id': targetUserId,
      'sender_user_id': _user!['id'],
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $targetUsername…')),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (ctx, wsService, _) => Column(
        children: [
          // Connection status strip
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: wsService.isConnected
                ? kGreen.withOpacity(0.08)
                : kRed.withOpacity(0.08),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: wsService.isConnected ? kGreen : kRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  wsService.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 11,
                    color: wsService.isConnected ? kGreen : kRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: kTextMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet. Say hi! 👋',
                          style: TextStyle(color: kTextSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (_, i) => _buildMessageBubble(messages[i]),
                  ),
          ),

          // Reply Preview Box (If replying to a message)
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: kDarkSurface2,
                border: Border(top: BorderSide(color: kDarkBorder, width: 0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, color: kAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyMessage!['username'] ?? 'User'}',
                          style: const TextStyle(
                            color: kAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyMessage!['message_text'] ?? (_replyMessage!['audio_url'] != null ? 'Voice note' : ''),
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
                  GestureDetector(
                    onTap: () => setState(() => _replyMessage = null),
                    child: const Icon(Icons.close_rounded, color: kTextMuted, size: 20),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: kDarkSurface,
              border: Border(top: BorderSide(color: kDarkBorder, width: 0.8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _isRecording
                      ? Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: kRed.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: kRed, shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Recording…',
                                style: TextStyle(color: kRed, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : TextField(
                          controller: _textController,
                          maxLines: null,
                          style: const TextStyle(color: kTextPrimary),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Message…',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(22)),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(22)),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(22)),
                              borderSide: BorderSide(color: kAccent, width: 1.2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(maxHeight: 120),
                          ),
                        ),
                ),
                const SizedBox(width: 8),

                // Send / Mic button
                _textController.text.trim().isNotEmpty
                    ? GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 42, height: 42,
                          decoration: const BoxDecoration(
                            gradient: kAccentGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: kTextPrimary, size: 18),
                        ),
                      )
                    : GestureDetector(
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd:   (_) => _stopRecordingAndSend(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width:  _isRecording ? 50 : 42,
                          height: _isRecording ? 50 : 42,
                          decoration: BoxDecoration(
                            color: _isRecording ? kRed : kAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded, color: kTextPrimary, size: 22),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
