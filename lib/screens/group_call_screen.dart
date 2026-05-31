import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/group_webrtc_service.dart';
import '../theme.dart';

class GroupCallScreen extends StatefulWidget {
  final int currentUserId;
  const GroupCallScreen({super.key, required this.currentUserId});

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _remoteRenderers = {};
  bool _isMicMuted  = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    final service = context.read<GroupWebRTCService>();
    service.addListener(_onServiceUpdate);
    _syncStreams();
    service.joinGroupCall(widget.currentUserId);
  }

  void _onServiceUpdate() => _syncStreams();

  void _syncStreams() {
    final service = context.read<GroupWebRTCService>();
    if (service.localStream != null &&
        _localRenderer.srcObject != service.localStream) {
      setState(() => _localRenderer.srcObject = service.localStream);
    }

    for (var entry in service.remoteStreams.entries) {
      final userId = entry.key;
      final stream = entry.value;
      if (!_remoteRenderers.containsKey(userId)) {
        final renderer = RTCVideoRenderer();
        renderer.initialize().then((_) {
          setState(() {
            renderer.srcObject = stream;
            _remoteRenderers[userId] = renderer;
          });
        });
      } else if (_remoteRenderers[userId]!.srcObject != stream) {
        setState(() => _remoteRenderers[userId]!.srcObject = stream);
      }
    }

    final userIds = service.remoteStreams.keys.toList();
    _remoteRenderers.keys
        .where((id) => !userIds.contains(id))
        .toList()
        .forEach((id) => _remoteRenderers.remove(id)?.dispose());

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final service = context.read<GroupWebRTCService>();
    service.removeListener(_onServiceUpdate);
    service.leaveGroupCall();
    _localRenderer.dispose();
    for (var r in _remoteRenderers.values) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStreams = 1 + _remoteRenderers.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video grid ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: kTextPrimary),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Group Call',
                            style: TextStyle(
                              color: kTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$totalStreams participant${totalStreams != 1 ? 's' : ''}',
                            style: const TextStyle(color: kTextSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGreen.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            const Text('Live', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Video grid
                Expanded(child: _buildVideoGrid(totalStreams)),
              ],
            ),
          ),

          // ── Controls bar ────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 32, right: 32,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.black.withValues(alpha: 0.0)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlBtn(
                    icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMicMuted ? 'Muted' : 'Mute',
                    active: _isMicMuted,
                    onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                  ),
                  // End call
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                          child: const Icon(Icons.call_end_rounded, color: kTextPrimary, size: 28),
                        ),
                        const SizedBox(height: 6),
                        const Text('End', style: TextStyle(color: kRed, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  _controlBtn(
                    icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    label: _isCameraOff ? 'Cam Off' : 'Camera',
                    active: _isCameraOff,
                    onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(int total) {
    final List<Widget> views = [
      _buildVideoTile(_localRenderer, 'You', isLocal: true),
      ..._remoteRenderers.entries.map(
        (e) => _buildVideoTile(e.value, 'User ${e.key}'),
      ),
    ];

    if (total == 1) return views.first;
    if (total == 2) {
      return Column(children: views.map((v) => Expanded(child: v)).toList());
    }
    return GridView.count(
      crossAxisCount: total <= 4 ? 2 : 3,
      padding: const EdgeInsets.all(4),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: views,
    );
  }

  Widget _buildVideoTile(RTCVideoRenderer renderer, String label, {bool isLocal = false}) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLocal ? kAccent.withValues(alpha: 0.6) : kDarkBorder,
          width: isLocal ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: isLocal,
            ),
            // Label
            Positioned(
              bottom: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: kTextPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: active ? kRed : kDarkSurface2,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kTextPrimary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? kRed : kTextSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
