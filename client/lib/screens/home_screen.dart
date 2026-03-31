import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _codeCopied = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code.replaceAll('-', '')));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _codeCopied = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 700;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.6),
                            width: 1.5),
                        color: AppTheme.accentGlow,
                      ),
                      child: const Icon(Icons.lan_rounded,
                          color: AppTheme.accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'RemoteApp',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.accent,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const Spacer(),
                    // Avatar / logout
                    GestureDetector(
                      onTap: () => _showLogoutDialog(context, auth),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.glassWhite,
                          border:
                              Border.all(color: AppTheme.glassBorder, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            auth.fullName.isNotEmpty
                                ? auth.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main content ───────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? (w - 540) / 2 : 20,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Text(
                        'Hello, ${auth.fullName.split(' ').first} 👋',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your device is online and ready to connect',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // ── Device Code Card ──────────────────────────────────
                      GlassCard(
                        borderColor: AppTheme.accent.withOpacity(0.3),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Online indicator
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, __) => Opacity(
                                    opacity: _pulseAnim.value,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Your Device Code',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                        letterSpacing: 1,
                                      ),
                                ),
                                const Spacer(),
                                // Copy button
                                GestureDetector(
                                  onTap: () => _copyCode(auth.deviceCode),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _codeCopied
                                          ? AppTheme.success.withOpacity(0.15)
                                          : AppTheme.accentGlow,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _codeCopied
                                            ? AppTheme.success.withOpacity(0.4)
                                            : AppTheme.accent.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _codeCopied
                                              ? Icons.check_rounded
                                              : Icons.copy_rounded,
                                          color: _codeCopied
                                              ? AppTheme.success
                                              : AppTheme.accent,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _codeCopied ? 'Copied!' : 'Copy',
                                          style: TextStyle(
                                            color: _codeCopied
                                                ? AppTheme.success
                                                : AppTheme.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // The big code display
                            Center(
                              child: _DeviceCodeDisplay(code: auth.deviceCode),
                            ),
                            const SizedBox(height: 16),

                            // Info text
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.glassWhite,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: AppTheme.textHint, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Share this code to let others connect to your device',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Quick Actions ─────────────────────────────────────
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: isWide ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        children: const [
                          _ActionTile(
                            icon: Icons.computer_rounded,
                            label: 'Connect',
                            subtitle: 'Enter device code',
                            color: AppTheme.accent,
                            route: '/connect',
                          ),
                          _ActionTile(
                            icon: Icons.folder_open_rounded,
                            label: 'Files',
                            subtitle: 'Transfer files',
                            color: Color(0xFF4FC3F7),
                            route: '/files',
                          ),
                          _ActionTile(
                            icon: Icons.videocam_rounded,
                            label: 'Video Call',
                            subtitle: 'Start a call',
                            color: Color(0xFF81C784),
                            route: '/call',
                          ),
                          _ActionTile(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Messages',
                            subtitle: 'Send messages',
                            color: Color(0xFFCE93D8),
                            route: '/messages',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Coming soon banner ────────────────────────────────
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGlow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.rocket_launch_rounded,
                                  color: AppTheme.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phase 2 coming soon',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    'Remote control, screen sharing & more',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text('Sign out?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('You will be signed out of your account.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await auth.logout();
              if (context.mounted)
                Navigator.pushReplacementNamed(context, '/login');
            },
            child:
                const Text('Sign out', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Device code display ───────────────────────────────────────────────────────
class _DeviceCodeDisplay extends StatelessWidget {
  final String code; // format: XXXX-XXXX-XXXX
  const _DeviceCodeDisplay({required this.code});

  @override
  Widget build(BuildContext context) {
    final parts = code.split('-');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          _CodeBlock(text: parts[i]),
          if (i < parts.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '—',
                style: TextStyle(
                  color: AppTheme.accent.withOpacity(0.4),
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentGlow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Action tile ───────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle, route;
  final Color color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Routes will be wired in Phase 2
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label — Coming in Phase 2'),
            backgroundColor: AppTheme.bgCard,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder, width: 1),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
