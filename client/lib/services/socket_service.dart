import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

typedef JsonCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;

  static bool get isConnected => _isConnected;

  // ── Connect ───────────────────────────────────────────────
  static void connect() {
    if (_socket != null && _isConnected) return;

    final url = ApiService.socketUrl; // auto Android vs desktop

    _socket = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      print('[Socket] Connected to $url');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((e) => print('[Socket] Connect error: $e'));
    _socket!.onError((e) => print('[Socket] Error: $e'));
  }

  // ── Device ────────────────────────────────────────────────
  static void registerDevice({
    required String deviceCode,
    required int userId,
    required String fullName,
  }) =>
      _emit('device:register', {
        'deviceCode': deviceCode,
        'userId': userId,
        'fullName': fullName,
      });

  static void checkDeviceOnline(String deviceCode) =>
      _emit('device:check_online', {'deviceCode': deviceCode});

  // ── Connection ────────────────────────────────────────────
  static void sendConnectionRequest({
    required String targetCode,
    required String initiatorCode,
    required String initiatorName,
  }) =>
      _emit('connection:request', {
        'targetCode': targetCode,
        'initiatorCode': initiatorCode,
        'initiatorName': initiatorName,
      });

  static void cancelConnectionRequest({
    required String targetCode,
    required String initiatorCode,
  }) =>
      _emit('connection:cancel', {
        'targetCode': targetCode,
        'initiatorCode': initiatorCode,
      });

  static void respondToConnection({
    required String initiatorSocketId,
    required String initiatorCode,
    required String targetCode,
    required bool accepted,
  }) =>
      _emit('connection:respond', {
        'initiatorSocketId': initiatorSocketId,
        'initiatorCode': initiatorCode,
        'targetCode': targetCode,
        'accepted': accepted,
      });

  // ── WebRTC signaling ──────────────────────────────────────
  static void sendCallRequest({
    required String targetSocketId,
    required String callerName,
    required String callerCode,
  }) =>
      _emit('webrtc:call_request', {
        'targetSocketId': targetSocketId,
        'callerName': callerName,
        'callerCode': callerCode,
      });

  static void sendCallAccepted(String targetSocketId) =>
      _emit('webrtc:call_accepted', {'targetSocketId': targetSocketId});

  static void sendCallRejected(String targetSocketId) =>
      _emit('webrtc:call_rejected', {'targetSocketId': targetSocketId});

  static void sendCallEnded(String targetSocketId) =>
      _emit('webrtc:call_ended', {'targetSocketId': targetSocketId});

  static void sendOffer({
    required String targetSocketId,
    required Map<String, dynamic> offer,
  }) =>
      _emit('webrtc:offer', {'targetSocketId': targetSocketId, 'offer': offer});

  static void sendAnswer({
    required String targetSocketId,
    required Map<String, dynamic> answer,
  }) =>
      _emit('webrtc:answer',
          {'targetSocketId': targetSocketId, 'answer': answer});

  static void sendIceCandidate({
    required String targetSocketId,
    required Map<String, dynamic> candidate,
  }) =>
      _emit('webrtc:candidate',
          {'targetSocketId': targetSocketId, 'candidate': candidate});

  // ── Listeners ─────────────────────────────────────────────
  static void on(String event, JsonCallback callback) {
    _socket?.on(event, (data) {
      if (data is Map) callback(Map<String, dynamic>.from(data));
    });
  }

  static void off(String event) => _socket?.off(event);

  // ── Disconnect ────────────────────────────────────────────
  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  // ── Emit helper ───────────────────────────────────────────
  static void _emit(String event, Map<String, dynamic> data) {
    if (_socket == null || !_isConnected) {
      print('[Socket] Not connected — cannot emit: $event');
      return;
    }
    _socket!.emit(event, data);
  }
}
