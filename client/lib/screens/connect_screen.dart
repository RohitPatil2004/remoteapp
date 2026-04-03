import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../providers/auth_provider.dart';
import '../providers/connection_provider.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  // 3 controllers for each 4-digit segment
  final _seg1 = TextEditingController();
  final _seg2 = TextEditingController();
  final _seg3 = TextEditingController();
  final _focus1 = FocusNode();
  final _focus2 = FocusNode();
  final _focus3 = FocusNode();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    // Auto-advance between segments
    _seg1.addListener(() {
      if (_seg1.text.length == 4) _focus2.requestFocus();
    });
    _seg2.addListener(() {
      if (_seg2.text.length == 4) _focus3.requestFocus();
      if (_seg2.text.isEmpty) _focus1.requestFocus();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _seg1.dispose();
    _seg2.dispose();
    _seg3.dispose();
    _focus1.dispose();
    _focus2.dispose();
    _focus3.dispose();
    super.dispose();
  }

  String get _fullCode =>
      '${_seg1.text.trim()}${_seg2.text.trim()}${_seg3.text.trim()}';

  bool get _codeComplete => _fullCode.length == 12;

  void _clearCode() {
    _seg1.clear();
    _seg2.clear();
    _seg3.clear();
    _focus1.requestFocus();
    context.read<ConnectionProvider>().reset();
  }

  Future<void> _lookup() async {
    if (!_codeComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Enter the full 12-digit code'),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<ConnectionProvider>().lookupDevice(_fullCode);
  }

  void _sendRequest() {
    final auth = context.read<AuthProvider>();
    final conn = context.read<ConnectionProvider>();
    conn.sendRequest(
      initiatorCode: auth.user!['device_code'],
      initiatorName: auth.fullName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 700;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textSecondary, size: 20),
                      onPressed: () {
                        conn.reset();
                        Navigator.pop(context);
                      },
                    ),
                    Text(
                      'Connect to Device',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),

              // ── Content ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? (w - 500) / 2 : 20,
                    vertical: 24,
                  ),
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (_, child) => FadeTransition(
                      opacity: _fadeAnim,
                      child:
                          SlideTransition(position: _slideAnim, child: child),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Code input card ───────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.dialpad_rounded,
                                      color: AppTheme.accent, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Enter Device Code',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 17),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ask the other person to share their 12-digit code from their home screen.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),

                              // ── 3 segment inputs ──────────
                              Row(
                                children: [
                                  Expanded(
                                      child: _CodeSegmentField(
                                    controller: _seg1,
                                    focusNode: _focus1,
                                    autofocus: true,
                                  )),
                                  _Dash(),
                                  Expanded(
                                      child: _CodeSegmentField(
                                    controller: _seg2,
                                    focusNode: _focus2,
                                  )),
                                  _Dash(),
                                  Expanded(
                                      child: _CodeSegmentField(
                                    controller: _seg3,
                                    focusNode: _focus3,
                                    onDone: _lookup,
                                  )),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ── Action buttons ────────────
                              Row(
                                children: [
                                  // Clear
                                  if (_fullCode.isNotEmpty)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _clearCode,
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 16),
                                        label: const Text('Clear'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.textSecondary,
                                          side: const BorderSide(
                                              color: AppTheme.glassBorder),
                                          minimumSize: const Size(0, 48),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  if (_fullCode.isNotEmpty)
                                    const SizedBox(width: 12),

                                  // Look up
                                  Expanded(
                                    flex: 2,
                                    child: _GlowButton(
                                      label: conn.isLooking
                                          ? 'Looking up...'
                                          : 'Find Device',
                                      isLoading: conn.isLooking,
                                      enabled: _codeComplete,
                                      onPressed: _lookup,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── State-based panels ────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _buildStatusPanel(conn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status panels (shown below code input) ──────────────────
  Widget _buildStatusPanel(ConnectionProvider conn) {
    switch (conn.status) {
      // Device found — show info card
      case ConnectionStatus.found:
        return _DeviceInfoCard(
          device: conn.targetDevice!,
          onConnect: _sendRequest,
          onCancel: _clearCode,
        );

      // Waiting for permission
      case ConnectionStatus.requesting:
        return _WaitingCard(
          deviceName: conn.targetDevice?['owner_name'] ?? 'Unknown',
          onCancel: () {
            final auth = context.read<AuthProvider>();
            conn.cancelRequest(auth.user!['device_code']);
            _clearCode();
          },
        );

      // Accepted!
      case ConnectionStatus.accepted:
        return _AcceptedCard(
          deviceName: conn.targetDevice?['owner_name'] ?? 'Unknown',
          onContinue: () {
            // Phase 2b: navigate to session screen
            ScaffoldMessenger.of(context).showSnackBar(
              _snackBar('Connected! Session screen coming in Phase 2b.'),
            );
          },
        );

      // Rejected
      case ConnectionStatus.rejected:
        return _RejectedCard(
          message: conn.errorMessage ?? 'Connection was declined.',
          onRetry: _clearCode,
        );

      // Target offline
      case ConnectionStatus.offline:
        return _OfflineCard(onRetry: _clearCode);

      // Error (device not found etc.)
      case ConnectionStatus.error:
        return _ErrorCard(
          message: conn.errorMessage ?? 'Something went wrong.',
          onRetry: _clearCode,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

// ── Code segment input field ────────────────────────────────────────────────
class _CodeSegmentField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback? onDone;

  const _CodeSegmentField({
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 4,
      style: const TextStyle(
        color: AppTheme.accent,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: AppTheme.accentGlow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppTheme.accent.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        hintText: '0000',
        hintStyle: TextStyle(
          color: AppTheme.accent.withOpacity(0.2),
          fontSize: 26,
          letterSpacing: 6,
          fontFamily: 'monospace',
        ),
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => onDone?.call(),
    );
  }
}

class _Dash extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('—',
            style: TextStyle(
                color: AppTheme.accent.withOpacity(0.3),
                fontSize: 22,
                fontWeight: FontWeight.w300)),
      );
}

// ── Glow button ───────────────────────────────────────────────────────────────
class _GlowButton extends StatelessWidget {
  final String label;
  final bool isLoading, enabled;
  final VoidCallback onPressed;

  const _GlowButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: (!enabled || isLoading)
            ? []
            : [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: (!enabled || isLoading) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppTheme.bgDark),
                ))
            : Text(label),
      ),
    );
  }
}

// ── Device info card ──────────────────────────────────────────────────────────
class _DeviceInfoCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onConnect, onCancel;

  const _DeviceInfoCard({
    required this.device,
    required this.onConnect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = device['is_online'] == true;
    final code = device['device_code_display'] ?? device['device_code'] ?? '';

    return GlassCard(
      borderColor: AppTheme.success.withOpacity(0.3),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.success.withOpacity(0.15),
                  border: Border.all(
                      color: AppTheme.success.withOpacity(0.4), width: 1),
                ),
                child: Center(
                  child: Text(
                    (device['owner_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device['owner_name'] ?? 'Unknown Device',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Online / offline badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppTheme.success.withOpacity(0.12)
                      : AppTheme.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? AppTheme.success.withOpacity(0.4)
                        : AppTheme.textHint.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? AppTheme.success : AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? AppTheme.success : AppTheme.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.glassWhite,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.send_rounded : Icons.wifi_off_rounded,
                  color: isOnline ? AppTheme.accent : AppTheme.textHint,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'A permission request will be sent to this device. They must accept before you can connect.'
                        : 'This device appears to be offline. Ask them to open RemoteApp first.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.glassBorder),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _GlowButton(
                  label: isOnline ? 'Send Request' : 'Try Anyway',
                  isLoading: false,
                  enabled: true,
                  onPressed: onConnect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Waiting card ──────────────────────────────────────────────────────────────
class _WaitingCard extends StatefulWidget {
  final String deviceName;
  final VoidCallback onCancel;
  const _WaitingCard({required this.deviceName, required this.onCancel});

  @override
  State<_WaitingCard> createState() => _WaitingCardState();
}

class _WaitingCardState extends State<_WaitingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.accent.withOpacity(0.3),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: _pulse.value,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGlow,
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    color: AppTheme.accent, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for permission...',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.deviceName} needs to accept your request on their device.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Cancel Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: BorderSide(color: AppTheme.error.withOpacity(0.4)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Accepted card ─────────────────────────────────────────────────────────────
class _AcceptedCard extends StatelessWidget {
  final String deviceName;
  final VoidCallback onContinue;
  const _AcceptedCard({required this.deviceName, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.success.withOpacity(0.4),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.success.withOpacity(0.12),
              border: Border.all(
                  color: AppTheme.success.withOpacity(0.5), width: 1.5),
            ),
            child: const Icon(Icons.check_rounded,
                color: AppTheme.success, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Connected!',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppTheme.success),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$deviceName accepted your request.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _GlowButton(
            label: 'Continue to Session',
            isLoading: false,
            enabled: true,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

// ── Rejected card ─────────────────────────────────────────────────────────────
class _RejectedCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RejectedCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.error.withOpacity(0.3),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.error.withOpacity(0.12),
              border: Border.all(
                  color: AppTheme.error.withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.close_rounded,
                color: AppTheme.error, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Request Declined',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppTheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _GlowButton(
            label: 'Try Again',
            isLoading: false,
            enabled: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Offline card ──────────────────────────────────────────────────────────────
class _OfflineCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.textHint.withOpacity(0.2),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.glassWhite,
              border: Border.all(color: AppTheme.glassBorder, width: 1),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppTheme.textSecondary, size: 34),
          ),
          const SizedBox(height: 20),
          Text(
            'Device Offline',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This device is not currently online.\nAsk them to open RemoteApp and try again.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _GlowButton(
            label: 'Try Different Code',
            isLoading: false,
            enabled: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.error.withOpacity(0.25),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Not Found',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            child: const Icon(Icons.refresh_rounded,
                color: AppTheme.accent, size: 22),
          ),
        ],
      ),
    );
  }
}
