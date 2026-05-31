import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'websocket_service.dart';

class WebRTCService extends ChangeNotifier {
  final WebSocketService _wsService;
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // Stored for signaling
  int? currentUserId;
  int? remoteUserId;

  WebRTCService(this._wsService);

  // Configuration for ICE servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _offerSdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  // 1. Initialize local stream (Camera/Mic)
  Future<void> initLocalStream() async {
    final statusCam = await Permission.camera.request();
    final statusMic = await Permission.microphone.request();

    if (statusCam.isGranted && statusMic.isGranted) {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
      };

      try {
        localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        notifyListeners();
      } catch (e) {
        print('Error getting user media: $e');
      }
    } else {
      print('Camera or Microphone permissions denied.');
    }
  }

  // 2. Initialize Peer Connection
  Future<void> _createPeerConnection() async {
    _peerConnection?.close();
    _peerConnection = await createPeerConnection(_configuration);

    // Add local stream tracks to PC
    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, localStream!);
      });
    }

    // Handle remote stream
    _peerConnection!.onAddStream = (stream) {
      remoteStream = stream;
      notifyListeners();
    };

    // Handle ICE Candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null && remoteUserId != null && currentUserId != null) {
        _wsService.send('webrtc_ice_candidate', {
          'target_user_id': remoteUserId,
          'sender_user_id': currentUserId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      }
    };
  }

  // 3. Create Offer
  Future<void> createOffer(int targetId, int myId) async {
    currentUserId = myId;
    remoteUserId = targetId;

    await _createPeerConnection();

    final offer = await _peerConnection!.createOffer(_offerSdpConstraints);
    await _peerConnection!.setLocalDescription(offer);

    _wsService.send('webrtc_offer', {
      'target_user_id': targetId,
      'sender_user_id': myId,
      'sdp': {
        'type': offer.type,
        'sdp': offer.sdp,
      }
    });
  }

  // 4. Create Answer
  Future<void> createAnswer(Map<String, dynamic> offerSdp, int targetId, int myId) async {
    currentUserId = myId;
    remoteUserId = targetId;

    await _createPeerConnection();

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offerSdp['sdp'], offerSdp['type']),
    );

    final answer = await _peerConnection!.createAnswer(_offerSdpConstraints);
    await _peerConnection!.setLocalDescription(answer);

    _wsService.send('webrtc_answer', {
      'target_user_id': targetId,
      'sender_user_id': myId,
      'sdp': {
        'type': answer.type,
        'sdp': answer.sdp,
      }
    });
  }

  // 5. Handle Answer
  Future<void> handleAnswer(Map<String, dynamic> answerSdp) async {
    if (_peerConnection != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answerSdp['sdp'], answerSdp['type']),
      );
    }
  }

  // 6. Handle ICE Candidate
  Future<void> addIceCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection != null) {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        ),
      );
    }
  }

  // 7. End Call
  void endCall() {
    _peerConnection?.close();
    _peerConnection = null;
    remoteStream = null;
    remoteUserId = null;
    currentUserId = null;
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    localStream?.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }
}
