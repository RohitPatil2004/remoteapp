import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../providers/connection_provider.dart';

class FileTransferScreen extends StatelessWidget {
  const FileTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'File Transfer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Connected device banner
                      if (conn.hasActiveSession)
                        _ConnectedBanner(session: conn.activeSession!),
                      const SizedBox(height: 24),

                      // Coming soon card
                      Expanded(
                        child: GlassCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      const Color(0xFF4FC3F7).withOpacity(0.12),
                                ),
                                child: const Icon(Icons.folder_open_rounded,
                                    color: Color(0xFF4FC3F7), size: 40),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'File Transfer',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                conn.hasActiveSession
                                    ? 'Coming in Phase 3 — you will be able to\nsend and receive files with ${conn.activeSession!.peerName}.'
                                    : 'Connect to a device first to transfer files.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              _FeatureChip(label: 'Send any file type'),
                              const SizedBox(height: 8),
                              _FeatureChip(label: 'Progress tracking'),
                              const SizedBox(height: 8),
                              _FeatureChip(label: 'Transfer history'),
                            ],
                          ),
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
}

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.success, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ConnectedBanner extends StatelessWidget {
  final dynamic session;
  const _ConnectedBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.success),
          ),
          const SizedBox(width: 10),
          Text(
            'Connected to ${session.peerName}',
            style: const TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}
