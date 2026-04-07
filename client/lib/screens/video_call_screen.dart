import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  // ── WebRTC ────────────────────────────────────────────────
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _renderersReady = false;

  // ── State ─────────────────────────────────────────────────
  bool _callStarted = false;
  bool _callConnected = false;
  bool _micMuted = false;
  bool _cameraOff = false;
  bool _frontCamera = true;
  bool _isCalling = false;
  bool _controlsVisible = true;

  late AnimationController _controlsFade;

  // ── ICE servers ───────────────────────────────────────────
  final List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  // ── Offer/Answer constraints ──────────────────────────────
  final Map<String, dynamic> _offerConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  @override
  void initState() {
    super.initState();
    _controlsFade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300), value: 1.0);
    _initRenderers();
    _setupListeners();
  }

  // ── Initialize video renderers ────────────────────────────
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _renderersReady = true);
  }

  // ── Setup all socket listeners ────────────────────────────
  void _setupListeners() {
    final conn = context.read<ConnectionProvider>();

    // WebRTC signaling relay
    conn.onWebRTCEvent = (type, data) async {
      if (!mounted) return;
      switch (type) {
        case 'offer':
          await _handleOffer(data['offer']);
          break;
        case 'answer':
          await _handleAnswer(data['answer']);
          break;
        case 'candidate':
          await _handleCandidate(data['candidate']);
          break;
      }
    };

    // Incoming call
    SocketService.on('webrtc:incoming_call', (data) {
      if (!mounted) return;
      _showIncomingCallDialog(
        callerName: data['callerName']?.toString() ?? 'Unknown',
        callerSocketId: data['callerSocketId']?.toString() ?? '',
      );
    });

    // Peer accepted our call
    SocketService.on('webrtc:call_accepted', (_) async {
      if (!mounted) return;
      setState(() => _isCalling = false);
      await _startWebRTC(isInitiator: true);
    });

    // Peer rejected our call
    SocketService.on('webrtc:call_rejected', (_) {
      if (!mounted) return;
      setState(() {
        _isCalling = false;
        _callStarted = false;
      });
      _showSnack('Call was declined.');
    });

    // Peer ended the call
    SocketService.on('webrtc:call_ended', (_) {
      if (!mounted) return;
      _hangUp(notify: false);
    });
  }

  // ── Initiate outgoing call ────────────────────────────────
  Future<void> _initiateCall() async {
    final conn = context.read<ConnectionProvider>();
    final auth = context.read<AuthProvider>();

    if (!conn.hasActiveSession) {
      _showSnack(
          'No active connection. Go back and connect to a device first.');
      return;
    }

    setState(() {
      _callStarted = true;
      _isCalling = true;
    });

    SocketService.sendCallRequest(
      targetSocketId: conn.activeSession!.peerSocketId,
      callerName: auth.fullName,
      callerCode: auth.user!['device_code'],
    );
  }

  // ── Show incoming call dialog ─────────────────────────────
  void _showIncomingCallDialog({
    required String callerName,
    required String callerSocketId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGlow,
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: AppTheme.accent, size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'Incoming Video Call',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              callerName,
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              SocketService.sendCallRejected(callerSocketId);
            },
            icon: const Icon(Icons.call_end_rounded, size: 18),
            label: const Text('Decline'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              SocketService.sendCallAccepted(callerSocketId);
              setState(() => _callStarted = true);
              await _startWebRTC(isInitiator: false);
            },
            icon: const Icon(Icons.videocam_rounded, size: 18),
            label: const Text('Accept'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.success),
          ),
        ],
      ),
    );
  }

  // ── Start WebRTC session ──────────────────────────────────
  Future<void> _startWebRTC({required bool isInitiator}) async {
    await _getUserMedia();
    await _createPeerConnection();
    if (isInitiator) await _createAndSendOffer();
  }

  // ── Get local camera + mic ────────────────────────────────
  Future<void> _getUserMedia() async {
    // Use simpler constraints — avoids codec negotiation issues
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': {
        'facingMode': _frontCamera ? 'user' : 'environment',
        'width': {'ideal': 640, 'max': 1280},
        'height': {'ideal': 480, 'max': 720},
        'frameRate': {'ideal': 30, 'max': 30},
      },
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // Attach to renderer immediately
      _localRenderer.srcObject = _localStream;

      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Camera/mic error: $e');
      debugPrint('[WebRTC] getUserMedia error: $e');
    }
  }

  // ── Create peer connection ────────────────────────────────
  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan', // CRITICAL for Chrome + mobile
      'iceCandidatePoolSize': 10,
    };

    _peerConnection = await createPeerConnection(config);

    // Add all local tracks to peer connection
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Send ICE candidates to peer
    _peerConnection!.onIceCandidate = (candidate) {
      final conn = context.read<ConnectionProvider>();
      if (conn.hasActiveSession && candidate.candidate != null) {
        SocketService.sendIceCandidate(
          targetSocketId: conn.activeSession!.peerSocketId,
          candidate: candidate.toMap(),
        );
      }
    };

    // Receive remote tracks (unified-plan uses onTrack)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] onTrack: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        if (mounted) {
          setState(() {
            _remoteStream = stream;
            _remoteRenderer.srcObject = stream;
            if (event.track.kind == 'video') {
              _callConnected = true;
            }
          });
        }
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _callConnected = true);
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _hangUp(notify: true);
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE state: $state');
      if (!mounted) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        setState(() => _callConnected = true);
      }
    };
  }

  // ── Create offer (initiator) ──────────────────────────────
  Future<void> _createAndSendOffer() async {
    final offer = await _peerConnection!.createOffer(_offerConstraints);
    await _peerConnection!.setLocalDescription(offer);

    final conn = context.read<ConnectionProvider>();
    if (conn.hasActiveSession) {
      SocketService.sendOffer(
        targetSocketId: conn.activeSession!.peerSocketId,
        offer: offer.toMap(),
      );
      debugPrint('[WebRTC] Offer sent');
    }
  }

  // ── Handle offer (receiver) ───────────────────────────────
  Future<void> _handleOffer(dynamic offerData) async {
    debugPrint('[WebRTC] Received offer');
    if (_peerConnection == null) {
      await _getUserMedia();
      await _createPeerConnection();
    }

    final desc = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _peerConnection!.setRemoteDescription(desc);

    final answer = await _peerConnection!.createAnswer(_offerConstraints);
    await _peerConnection!.setLocalDescription(answer);

    final conn = context.read<ConnectionProvider>();
    if (conn.hasActiveSession) {
      SocketService.sendAnswer(
        targetSocketId: conn.activeSession!.peerSocketId,
        answer: answer.toMap(),
      );
      debugPrint('[WebRTC] Answer sent');
    }
  }

  // ── Handle answer ─────────────────────────────────────────
  Future<void> _handleAnswer(dynamic answerData) async {
    debugPrint('[WebRTC] Received answer');
    final desc = RTCSessionDescription(answerData['sdp'], answerData['type']);
    await _peerConnection?.setRemoteDescription(desc);
  }

  // ── Handle ICE candidate ──────────────────────────────────
  Future<void> _handleCandidate(dynamic data) async {
    if (data == null || data['candidate'] == null) return;
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    await _peerConnection?.addCandidate(candidate);
  }

  // ── Hang up ───────────────────────────────────────────────
  Future<void> _hangUp({required bool notify}) async {
    if (notify) {
      final conn = context.read<ConnectionProvider>();
      if (conn.hasActiveSession) {
        SocketService.sendCallEnded(conn.activeSession!.peerSocketId);
      }
    }

    // Stop all tracks first
    _localStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.getTracks().forEach((t) => t.stop());

    await _peerConnection?.close();
    _peerConnection = null;

    _localStream?.dispose();
    _remoteStream?.dispose();
    _localStream = null;
    _remoteStream = null;

    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    if (mounted) {
      setState(() {
        _callStarted = false;
        _callConnected = false;
        _isCalling = false;
      });
    }
  }

  // ── Toggle mic ────────────────────────────────────────────
  void _toggleMic() {
    final tracks = _localStream?.getAudioTracks();
    if (tracks != null && tracks.isNotEmpty) {
      setState(() => _micMuted = !_micMuted);
      tracks.first.enabled = !_micMuted;
    }
  }

  // ── Toggle camera ─────────────────────────────────────────
  void _toggleCamera() {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      setState(() => _cameraOff = !_cameraOff);
      tracks.first.enabled = !_cameraOff;
    }
  }

  // ── Switch front/back camera ──────────────────────────────
  Future<void> _switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
      setState(() => _frontCamera = !_frontCamera);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _controlsVisible ? _controlsFade.forward() : _controlsFade.reverse();
  }

  @override
  void dispose() {
    _controlsFade.dispose();
    _hangUp(notify: false);
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    SocketService.off('webrtc:incoming_call');
    SocketService.off('webrtc:call_accepted');
    SocketService.off('webrtc:call_rejected');
    SocketService.off('webrtc:call_ended');
    final conn = context.read<ConnectionProvider>();
    conn.onWebRTCEvent = null;
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ── REMOTE VIDEO (full screen background) ─────────
            if (_callConnected && _renderersReady)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false,
                ),
              )
            else
              _buildWaitingView(conn),

            // ── LOCAL VIDEO (picture-in-picture) ──────────────
            if (_callStarted && _renderersReady && _localStream != null)
              Positioned(
                right: 16,
                bottom: 130,
                child: GestureDetector(
                  onTap: () {}, // prevent controls toggle on PiP tap
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 120,
                      height: 170,
                      color: Colors.black,
                      child: _cameraOff
                          ? Container(
                              color: const Color(0xFF1A1A26),
                              child: const Center(
                                child: Icon(Icons.videocam_off_rounded,
                                    color: Colors.white38, size: 30),
                              ),
                            )
                          : RTCVideoView(
                              _localRenderer,
                              mirror: _frontCamera,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                    ),
                  ),
                ),
              ),

            // ── TOP BAR ───────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _controlsFade,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(4, 8, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 20),
                          onPressed: () {
                            if (_callStarted) _hangUp(notify: true);
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conn.hasActiveSession
                                    ? conn.activeSession!.peerName
                                    : 'Video Call',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _callConnected
                                    ? 'Connected'
                                    : _isCalling
                                        ? 'Calling...'
                                        : _callStarted
                                            ? 'Connecting...'
                                            : 'Ready',
                                style: TextStyle(
                                  color: _callConnected
                                      ? AppTheme.success
                                      : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_callStarted)
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded,
                                color: Colors.white70),
                            onPressed: _switchCamera,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── BOTTOM CONTROLS ───────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _controlsFade,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: _callStarted
                      ? _buildInCallControls()
                      : _buildStartCallButton(conn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Waiting / idle view ───────────────────────────────────
  Widget _buildWaitingView(ConnectionProvider conn) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0F), Color(0xFF1A1A26)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGlow,
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(
                  conn.hasActiveSession
                      ? conn.activeSession!.peerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 42,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              conn.hasActiveSession
                  ? conn.activeSession!.peerName
                  : 'No Active Connection',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              conn.hasActiveSession
                  ? (_isCalling
                      ? 'Ringing...'
                      : _callStarted
                          ? 'Connecting...'
                          : 'Tap the button to start a video call')
                  : 'Go back and connect to a device first',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_isCalling) ...[
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Start call button ─────────────────────────────────────
  Widget _buildStartCallButton(ConnectionProvider conn) {
    final canCall = conn.hasActiveSession && !_isCalling;
    return Center(
      child: GestureDetector(
        onTap: canCall ? _initiateCall : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            color: canCall ? AppTheme.success : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(50),
            boxShadow: canCall
                ? [
                    BoxShadow(
                        color: AppTheme.success.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 6))
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                canCall
                    ? 'Start Video Call'
                    : conn.hasActiveSession
                        ? 'Calling...'
                        : 'No Device Connected',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── In-call controls ──────────────────────────────────────
  Widget _buildInCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CtrlBtn(
          icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: _micMuted ? 'Unmute' : 'Mute',
          active: _micMuted,
          onTap: _toggleMic,
        ),
        _CtrlBtn(
          icon:
              _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
          label: _cameraOff ? 'Cam On' : 'Cam Off',
          active: _cameraOff,
          onTap: _toggleCamera,
        ),

        // End call — big red
        GestureDetector(
          onTap: () => _hangUp(notify: true),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.error,
              boxShadow: [
                BoxShadow(
                    color: AppTheme.error.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.call_end_rounded,
                color: Colors.white, size: 30),
          ),
        ),

        _CtrlBtn(
          icon: Icons.flip_camera_ios_rounded,
          label: 'Flip',
          onTap: _switchCamera,
        ),
        _CtrlBtn(
          icon: Icons.volume_up_rounded,
          label: 'Speaker',
          onTap: () => _showSnack('Speaker toggle coming soon'),
        ),
      ],
    );
  }
}

// ── Control button ────────────────────────────────────────────────────────────
class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppTheme.error.withOpacity(0.3)
                  : Colors.white.withOpacity(0.18),
            ),
            child: Icon(icon,
                color: active ? AppTheme.error : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
