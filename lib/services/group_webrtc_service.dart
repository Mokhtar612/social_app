import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

class GroupWebRTCService extends ChangeNotifier {
  final WebSocketService _wsService;
  int? _currentUserId;
  bool _inCall = false;

  MediaStream? _localStream;
  final Map<int, RTCPeerConnection> _peerConnections = {};
  final Map<int, MediaStream> _remoteStreams = {};

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
    ]
  };

  GroupWebRTCService(this._wsService) {
    _wsService.addMessageListener(_handleMessage);
  }

  bool get inCall => _inCall;
  MediaStream? get localStream => _localStream;
  Map<int, MediaStream> get remoteStreams => _remoteStreams;

  Future<void> joinGroupCall(int currentUserId) async {
    _currentUserId = currentUserId;
    _inCall = true;
    notifyListeners();

    // 1. Get Local Stream
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
        }
      });
      notifyListeners();
    } catch (e) {
      print('Error getting user media: $e');
    }

    // 2. Tell the server we are joining the group
    _wsService.send('join_group_call', {});
  }

  Future<void> leaveGroupCall() async {
    if (!_inCall) return;
    
    _wsService.send('leave_group_call', {});
    
    _inCall = false;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    notifyListeners();
  }

  void _handleMessage(Map<String, dynamic> data) async {
    if (!_inCall) return;
    
    final type = data['type'];
    final payload = data['payload'] ?? {};

    switch (type) {
      case 'group_call_participants':
        // We just joined. The server gives us a list of existing users in the room.
        // We must initiate calls (create offer) to ALL of them.
        List<dynamic> users = payload['users'] ?? [];
        for (var userId in users) {
          int targetId = userId as int;
          await _createPeerConnection(targetId);
          await _createOffer(targetId);
        }
        break;

      case 'user_joined_group':
        // Someone else joined. They will send us an offer. We just prepare the PC.
        int newUserId = payload['user_id'];
        await _createPeerConnection(newUserId);
        break;

      case 'user_left_group':
        // Someone left. Cleanup their PC and Stream.
        int leftUserId = payload['user_id'];
        _removePeer(leftUserId);
        break;

      case 'webrtc_offer':
        int senderId = payload['sender_user_id'];
        if (!_peerConnections.containsKey(senderId)) {
          await _createPeerConnection(senderId);
        }
        final pc = _peerConnections[senderId]!;
        await pc.setRemoteDescription(
          RTCSessionDescription(payload['sdp']['sdp'], payload['sdp']['type']),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _wsService.send('webrtc_answer', {
          'target_user_id': senderId,
          'sender_user_id': _currentUserId,
          'sdp': {'sdp': answer.sdp, 'type': answer.type}
        });
        break;

      case 'webrtc_answer':
        int answererId = payload['sender_user_id'];
        if (_peerConnections.containsKey(answererId)) {
          await _peerConnections[answererId]!.setRemoteDescription(
            RTCSessionDescription(payload['sdp']['sdp'], payload['sdp']['type']),
          );
        }
        break;

      case 'webrtc_ice_candidate':
        int candidateSenderId = payload['sender_user_id'];
        if (_peerConnections.containsKey(candidateSenderId)) {
          await _peerConnections[candidateSenderId]!.addCandidate(
            RTCIceCandidate(
              payload['candidate']['candidate'],
              payload['candidate']['sdpMid'],
              payload['candidate']['sdpMLineIndex'],
            ),
          );
        }
        break;
    }
  }

  Future<void> _createPeerConnection(int targetUserId) async {
    if (_peerConnections.containsKey(targetUserId)) return;

    RTCPeerConnection pc = await createPeerConnection(_configuration);
    _peerConnections[targetUserId] = pc;

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (candidate) {
      _wsService.send('webrtc_ice_candidate', {
        'target_user_id': targetUserId,
        'sender_user_id': _currentUserId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    pc.onAddStream = (stream) {
      _remoteStreams[targetUserId] = stream;
      notifyListeners();
    };

    pc.onRemoveStream = (stream) {
      _remoteStreams.remove(targetUserId);
      notifyListeners();
    };
  }

  Future<void> _createOffer(int targetUserId) async {
    final pc = _peerConnections[targetUserId];
    if (pc == null) return;

    try {
      RTCSessionDescription offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _wsService.send('webrtc_offer', {
        'target_user_id': targetUserId,
        'sender_user_id': _currentUserId,
        'sdp': {'sdp': offer.sdp, 'type': offer.type}
      });
    } catch (e) {
      print('Error creating offer for user $targetUserId: $e');
    }
  }

  void _removePeer(int userId) {
    if (_peerConnections.containsKey(userId)) {
      _peerConnections[userId]?.close();
      _peerConnections.remove(userId);
    }
    if (_remoteStreams.containsKey(userId)) {
      _remoteStreams.remove(userId);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.removeMessageListener(_handleMessage);
    leaveGroupCall();
    super.dispose();
  }
}
