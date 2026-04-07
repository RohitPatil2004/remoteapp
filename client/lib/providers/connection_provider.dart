import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

enum ConnectionStatus {
  idle,
  looking,
  found,
  requesting,
  accepted,
  rejected,
  offline,
  error,
}

class IncomingRequest {
  final String initiatorCode;
  final String initiatorName;
  final String initiatorSocketId;
  final String timestamp;
  IncomingRequest({
    required this.initiatorCode,
    required this.initiatorName,
    required this.initiatorSocketId,
    required this.timestamp,
  });
}

// Active session — set once connection is fully established
class ActiveSession {
  final String peerName;
  final String peerCode;
  final String peerSocketId;
  final DateTime connectedAt;
  ActiveSession({
    required this.peerName,
    required this.peerCode,
    required this.peerSocketId,
    required this.connectedAt,
  });
}

class ConnectionProvider extends ChangeNotifier {
  // ── Initiator state ───────────────────────────────────────
  ConnectionStatus _status = ConnectionStatus.idle;
  Map<String, dynamic>? _targetDevice;
  String? _errorMessage;
  String? _connectedTargetSocketId;

  ConnectionStatus get status => _status;
  Map<String, dynamic>? get targetDevice => _targetDevice;
  String? get errorMessage => _errorMessage;
  String? get connectedTargetSocketId => _connectedTargetSocketId;

  bool get isIdle => _status == ConnectionStatus.idle;
  bool get isLooking => _status == ConnectionStatus.looking;
  bool get isFound => _status == ConnectionStatus.found;
  bool get isRequesting => _status == ConnectionStatus.requesting;
  bool get isAccepted => _status == ConnectionStatus.accepted;
  bool get isRejected => _status == ConnectionStatus.rejected;
  bool get isOffline => _status == ConnectionStatus.offline;

  // ── Receiver state ────────────────────────────────────────
  IncomingRequest? _incomingRequest;
  bool _isRegistered = false;

  IncomingRequest? get incomingRequest => _incomingRequest;
  bool get hasIncomingRequest => _incomingRequest != null;

  // ── Active session (both sides) ───────────────────────────
  ActiveSession? _activeSession;
  ActiveSession? get activeSession => _activeSession;
  bool get hasActiveSession => _activeSession != null;

  void _setStatus(ConnectionStatus s) {
    _status = s;
    notifyListeners();
  }

  // ── Register device ───────────────────────────────────────
  void registerDevice(Map<String, dynamic> user) {
    if (_isRegistered) return;
    SocketService.connect();
    Future.delayed(const Duration(milliseconds: 800), () {
      SocketService.registerDevice(
        deviceCode: user['device_code'],
        userId: user['id'],
        fullName: user['full_name'],
      );
      _isRegistered = true;
    });
    _listenForAllEvents();
  }

  // ── Look up target device ─────────────────────────────────
  Future<void> lookupDevice(String code) async {
    _setStatus(ConnectionStatus.looking);
    _errorMessage = null;
    _targetDevice = null;
    try {
      final res = await ApiService.lookupDevice(code);
      if (res['success'] == true) {
        _targetDevice = res['data'];
        _targetDevice!['is_online'] = false;
        SocketService.checkDeviceOnline(code.replaceAll('-', ''));
        _setStatus(ConnectionStatus.found);
      } else {
        _errorMessage = res['message'] ?? 'Device not found';
        _setStatus(ConnectionStatus.error);
      }
    } catch (_) {
      _errorMessage = 'Connection error. Is the server running?';
      _setStatus(ConnectionStatus.error);
    }
  }

  // ── Send permission request ───────────────────────────────
  void sendRequest(
      {required String initiatorCode, required String initiatorName}) {
    if (_targetDevice == null) return;
    SocketService.sendConnectionRequest(
      targetCode: _targetDevice!['device_code'],
      initiatorCode: initiatorCode,
      initiatorName: initiatorName,
    );
    _setStatus(ConnectionStatus.requesting);
  }

  // ── Cancel request ────────────────────────────────────────
  void cancelRequest(String initiatorCode) {
    if (_targetDevice == null) return;
    SocketService.cancelConnectionRequest(
      targetCode: _targetDevice!['device_code'],
      initiatorCode: initiatorCode,
    );
    reset();
  }

  // ── Accept incoming request (receiver) ───────────────────
  void acceptRequest(String myDeviceCode) {
    if (_incomingRequest == null) return;
    final req = _incomingRequest!;
    SocketService.respondToConnection(
      initiatorSocketId: req.initiatorSocketId,
      initiatorCode: req.initiatorCode,
      targetCode: myDeviceCode,
      accepted: true,
    );
    // Set active session on receiver side
    _activeSession = ActiveSession(
      peerName: req.initiatorName,
      peerCode: req.initiatorCode,
      peerSocketId: req.initiatorSocketId,
      connectedAt: DateTime.now(),
    );
    _incomingRequest = null;
    notifyListeners();
  }

  // ── Reject incoming request (receiver) ───────────────────
  void rejectRequest(String myDeviceCode) {
    if (_incomingRequest == null) return;
    SocketService.respondToConnection(
      initiatorSocketId: _incomingRequest!.initiatorSocketId,
      initiatorCode: _incomingRequest!.initiatorCode,
      targetCode: myDeviceCode,
      accepted: false,
    );
    _incomingRequest = null;
    notifyListeners();
  }

  // ── Disconnect active session ─────────────────────────────
  void disconnectSession() {
    _activeSession = null;
    reset();
  }

  // ── All socket events ─────────────────────────────────────
  void _listenForAllEvents() {
    SocketService.on('device:online_status', (data) {
      if (_targetDevice != null) {
        final code = (data['deviceCode'] ?? '').toString();
        final myTarget = (_targetDevice!['device_code'] ?? '').toString();
        if (code == myTarget) {
          _targetDevice!['is_online'] = data['isOnline'] ?? false;
          notifyListeners();
        }
      }
    });

    SocketService.on('connection:request_sent', (_) => notifyListeners());

    SocketService.on('connection:target_offline', (_) {
      _errorMessage = 'This device is currently offline.';
      _setStatus(ConnectionStatus.offline);
    });

    // Initiator: target accepted → set active session
    SocketService.on('connection:accepted', (data) {
      _connectedTargetSocketId = data['targetSocketId']?.toString();
      _activeSession = ActiveSession(
        peerName: _targetDevice?['owner_name'] ?? 'Unknown',
        peerCode: _targetDevice?['device_code'] ?? '',
        peerSocketId: _connectedTargetSocketId ?? '',
        connectedAt: DateTime.now(),
      );
      _setStatus(ConnectionStatus.accepted);
    });

    SocketService.on('connection:rejected', (data) {
      _errorMessage = data['message']?.toString() ?? 'Connection was declined.';
      _setStatus(ConnectionStatus.rejected);
    });

    // Receiver: incoming request
    SocketService.on('connection:incoming', (data) {
      _incomingRequest = IncomingRequest(
        initiatorCode: data['initiatorCode']?.toString() ?? '',
        initiatorName: data['initiatorName']?.toString() ?? 'Unknown',
        initiatorSocketId: data['initiatorSocketId']?.toString() ?? '',
        timestamp: data['timestamp']?.toString() ?? '',
      );
      notifyListeners();
    });

    SocketService.on('connection:cancelled', (_) {
      _incomingRequest = null;
      notifyListeners();
    });

    SocketService.on('connection:live', (data) {
      notifyListeners();
    });

    // WebRTC signaling for video call
    SocketService.on('webrtc:offer', (data) => _onWebRTCEvent('offer', data));
    SocketService.on('webrtc:answer', (data) => _onWebRTCEvent('answer', data));
    SocketService.on(
        'webrtc:candidate', (data) => _onWebRTCEvent('candidate', data));
  }

  // WebRTC event callbacks (set by VideoCallScreen)
  Function(String type, Map<String, dynamic> data)? onWebRTCEvent;

  void _onWebRTCEvent(String type, Map<String, dynamic> data) {
    onWebRTCEvent?.call(type, data);
  }

  // ── Reset ─────────────────────────────────────────────────
  void reset() {
    _status = ConnectionStatus.idle;
    _targetDevice = null;
    _errorMessage = null;
    _connectedTargetSocketId = null;
    notifyListeners();
  }

  void fullReset() {
    reset();
    _incomingRequest = null;
    _activeSession = null;
    _isRegistered = false;
    notifyListeners();
  }
}
