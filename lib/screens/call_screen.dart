import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CallScreen extends StatefulWidget {
  final int targetUserId;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.targetUserId,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer  = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isCameraOff = false;
  bool _isMicMuted  = false;
  void Function(Map<String, dynamic>)? _signalingListener;
  WebSocketService? _wsService;

  @override
  void initState() {
    super.initState();
    _wsService = context.read<WebSocketService>();
    _initRenderers();
    _startCall();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _startCall() async {
    final webrtcService   = context.read<WebRTCService>();
    final wsService       = _wsService!;
    final currentUserId   = await context.read<ApiService>().getUserId();
    if (currentUserId == null) return;

    await webrtcService.initLocalStream();
    setState(() {
      if (webrtcService.localStream != null) {
        _localRenderer.srcObject = webrtcService.localStream;
      }
    });

    webrtcService.addListener(_onStreamChanged);

    _signalingListener = (data) async {
      final type    = data['type'];
      final payload = data['payload'];
      if (payload['sender_user_id'] != widget.targetUserId &&
          payload['target_user_id'] != widget.targetUserId) return;

      if (type == 'webrtc_offer' && !widget.isCaller) {
        await webrtcService.createAnswer(payload['sdp'], payload['sender_user_id'], currentUserId);
      } else if (type == 'webrtc_answer' && widget.isCaller) {
        await webrtcService.handleAnswer(payload['sdp']);
      } else if (type == 'webrtc_ice_candidate') {
        await webrtcService.addIceCandidate(payload['candidate']);
      } else if (type == 'call_ended' || type == 'call_rejected') {
        _endCallLocally();
      }
    };
    wsService.addMessageListener(_signalingListener!);

    if (widget.isCaller) {
      await webrtcService.createOffer(widget.targetUserId, currentUserId);
    }
  }

  void _onStreamChanged() {
    final webrtcService = context.read<WebRTCService>();
    if (webrtcService.remoteStream != null &&
        _remoteRenderer.srcObject != webrtcService.remoteStream) {
      setState(() => _remoteRenderer.srcObject = webrtcService.remoteStream);
    }
  }

  void _toggleMic() {
    final webrtcService = context.read<WebRTCService>();
    if (webrtcService.localStream != null) {
      final track = webrtcService.localStream!.getAudioTracks()[0];
      track.enabled = !track.enabled;
      setState(() => _isMicMuted = !track.enabled);
    }
  }

  void _toggleCamera() {
    final webrtcService = context.read<WebRTCService>();
    if (webrtcService.localStream != null) {
      final track = webrtcService.localStream!.getVideoTracks()[0];
      track.enabled = !track.enabled;
      setState(() => _isCameraOff = !track.enabled);
    }
  }

  void _endCall() {
    final currentUserId = context.read<WebRTCService>().currentUserId;
    _wsService!.send('call_ended', {
      'target_user_id': widget.targetUserId,
      'sender_user_id': currentUserId,
    });
    _endCallLocally();
  }

  void _endCallLocally() {
    if (mounted) {
      final webrtcService = context.read<WebRTCService>();
      if (_signalingListener != null) {
        _wsService?.removeMessageListener(_signalingListener!);
        _signalingListener = null;
      }
      webrtcService.removeListener(_onStreamChanged);
      webrtcService.endCall();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    if (_signalingListener != null) {
      _wsService?.removeMessageListener(_signalingListener!);
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Remote video fullscreen ──────────────────────────────
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // ── Gradient overlay (bottom) ────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Gradient overlay (top) ───────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Back button ─────────────────────────────────────────
          Positioned(
            top: 50, left: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: _endCall,
                icon: const Icon(Icons.arrow_back_ios_rounded, color: kTextPrimary),
              ),
            ),
          ),

          // ── Call label top center ────────────────────────────────
          Positioned(
            top: 55, left: 0, right: 0,
            child: SafeArea(
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'User ${widget.targetUserId}',
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isCaller ? 'Calling…' : 'Connected',
                      style: const TextStyle(color: kTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Local PiP ───────────────────────────────────────────
          Positioned(
            right: 20, bottom: 130,
            width: 100, height: 148,
            child: Container(
              decoration: BoxDecoration(
                color: kDarkSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // ── Controls ────────────────────────────────────────────
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                    icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMicMuted ? 'Muted' : 'Mute',
                    color: _isMicMuted ? kRed : kDarkSurface2,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: 24),
                  // End call (larger)
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 68, height: 68,
                      decoration: const BoxDecoration(
                        color: kRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end_rounded, color: kTextPrimary, size: 30),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _controlButton(
                    icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    label: _isCameraOff ? 'Cam Off' : 'Camera',
                    color: _isCameraOff ? kRed : kDarkSurface2,
                    onTap: _toggleCamera,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: kTextPrimary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
