import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef JsonCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static const String _serverUrl = 'http://localhost:5000';

  static IO.Socket? _socket;
  static bool _isConnected = false;

  static bool get isConnected => _isConnected;

  // ── Connect to server ───────────────────────────────────────
  static void connect() {
    if (_socket != null && _isConnected) return;

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      print('[Socket] Connected to server');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('[Socket] Disconnected from server');
    });

    _socket!.onConnectError((err) {
      print('[Socket] Connection error: $err');
    });
  }

  // ── Register this device ────────────────────────────────────
  static void registerDevice({
    required String deviceCode,
    required int userId,
    required String fullName,
  }) {
    _emit('device:register', {
      'deviceCode': deviceCode,
      'userId': userId,
      'fullName': fullName,
    });
  }

  // ── Send connection request to target ───────────────────────
  static void sendConnectionRequest({
    required String targetCode,
    required String initiatorCode,
    required String initiatorName,
  }) {
    _emit('connection:request', {
      'targetCode': targetCode,
      'initiatorCode': initiatorCode,
      'initiatorName': initiatorName,
    });
  }

  // ── Cancel a pending connection request ─────────────────────
  static void cancelConnectionRequest({
    required String targetCode,
    required String initiatorCode,
  }) {
    _emit('connection:cancel', {
      'targetCode': targetCode,
      'initiatorCode': initiatorCode,
    });
  }

  // ── Respond to incoming connection (target side) ────────────
  static void respondToConnection({
    required String initiatorSocketId,
    required String initiatorCode,
    required String targetCode,
    required bool accepted,
  }) {
    _emit('connection:respond', {
      'initiatorSocketId': initiatorSocketId,
      'initiatorCode': initiatorCode,
      'targetCode': targetCode,
      'accepted': accepted,
    });
  }

  // ── Check if device is online ───────────────────────────────
  static void checkDeviceOnline(String deviceCode) {
    _emit('device:check_online', {'deviceCode': deviceCode});
  }

  // ── Event listeners ─────────────────────────────────────────
  static void on(String event, JsonCallback callback) {
    _socket?.on(event, (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  static void off(String event) {
    _socket?.off(event);
  }

  // ── Disconnect ──────────────────────────────────────────────
  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  // ── Internal emit helper ────────────────────────────────────
  static void _emit(String event, Map<String, dynamic> data) {
    if (_socket == null || !_isConnected) {
      print('[Socket] Not connected — cannot emit: $event');
      return;
    }
    _socket!.emit(event, data);
  }
}
