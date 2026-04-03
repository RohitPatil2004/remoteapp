import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

// ── Initiator connection status ───────────────────────────────────────────────
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

// ── Incoming request model (receiver side) ────────────────────────────────────
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

class ConnectionProvider extends ChangeNotifier {
  // ── Initiator state ───────────────────────────────────────────────────────
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

  // ── Receiver state ────────────────────────────────────────────────────────
  IncomingRequest? _incomingRequest;
  bool _isRegistered = false;

  IncomingRequest? get incomingRequest => _incomingRequest;
  bool get hasIncomingRequest => _incomingRequest != null;

  void _setStatus(ConnectionStatus s) {
    _status = s;
    notifyListeners();
  }

  // ── Register device with socket ───────────────────────────────────────────
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

  // ── Look up target device ─────────────────────────────────────────────────
  Future<void> lookupDevice(String code) async {
    _setStatus(ConnectionStatus.looking);
    _errorMessage = null;
    _targetDevice = null;

    try {
      final res = await ApiService.lookupDevice(code);
      if (res['success'] == true) {
        _targetDevice = res['data'];
        // Default offline until socket confirms
        _targetDevice!['is_online'] = false;

        // Check live online status via socket
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

  // ── Send permission request ───────────────────────────────────────────────
  void sendRequest({
    required String initiatorCode,
    required String initiatorName,
  }) {
    if (_targetDevice == null) return;

    SocketService.sendConnectionRequest(
      targetCode: _targetDevice!['device_code'],
      initiatorCode: initiatorCode,
      initiatorName: initiatorName,
    );

    _setStatus(ConnectionStatus.requesting);
  }

  // ── Cancel pending request ────────────────────────────────────────────────
  void cancelRequest(String initiatorCode) {
    if (_targetDevice == null) return;
    SocketService.cancelConnectionRequest(
      targetCode: _targetDevice!['device_code'],
      initiatorCode: initiatorCode,
    );
    reset();
  }

  // ── Receiver: accept incoming request ────────────────────────────────────
  void acceptRequest(String myDeviceCode) {
    if (_incomingRequest == null) return;

    SocketService.respondToConnection(
      initiatorSocketId: _incomingRequest!.initiatorSocketId,
      initiatorCode: _incomingRequest!.initiatorCode,
      targetCode: myDeviceCode,
      accepted: true,
    );

    _incomingRequest = null;
    notifyListeners();
  }

  // ── Receiver: reject incoming request ────────────────────────────────────
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

  // ── Listen for ALL socket events (both sides) ─────────────────────────────
  void _listenForAllEvents() {
    // ── INITIATOR events ──────────────────────────────────────

    // Device online status response
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

    // Request sent confirmation
    SocketService.on('connection:request_sent', (data) {
      notifyListeners();
    });

    // Target is offline
    SocketService.on('connection:target_offline', (data) {
      _errorMessage = 'This device is currently offline.';
      _setStatus(ConnectionStatus.offline);
    });

    // Target accepted our request
    SocketService.on('connection:accepted', (data) {
      _connectedTargetSocketId = data['targetSocketId']?.toString();
      _setStatus(ConnectionStatus.accepted);
    });

    // Target rejected our request
    SocketService.on('connection:rejected', (data) {
      _errorMessage = data['message']?.toString() ?? 'Connection was declined.';
      _setStatus(ConnectionStatus.rejected);
    });

    // ── RECEIVER events ───────────────────────────────────────

    // Someone is requesting to connect to us
    SocketService.on('connection:incoming', (data) {
      _incomingRequest = IncomingRequest(
        initiatorCode: data['initiatorCode']?.toString() ?? '',
        initiatorName: data['initiatorName']?.toString() ?? 'Unknown',
        initiatorSocketId: data['initiatorSocketId']?.toString() ?? '',
        timestamp: data['timestamp']?.toString() ?? '',
      );
      notifyListeners();
    });

    // Initiator cancelled their request before we responded
    SocketService.on('connection:cancelled', (data) {
      _incomingRequest = null;
      notifyListeners();
    });

    // We accepted — connection is now live on our end
    SocketService.on('connection:live', (data) {
      notifyListeners();
    });
  }

  // ── Reset initiator state ─────────────────────────────────────────────────
  void reset() {
    _status = ConnectionStatus.idle;
    _targetDevice = null;
    _errorMessage = null;
    _connectedTargetSocketId = null;
    notifyListeners();
  }

  // ── Full cleanup on logout ────────────────────────────────────────────────
  void fullReset() {
    reset();
    _incomingRequest = null;
    _isRegistered = false;
    notifyListeners();
  }
}
