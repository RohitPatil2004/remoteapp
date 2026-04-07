import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../providers/connection_provider.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
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
                      'Messages',
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
                      if (conn.hasActiveSession)
                        _ConnectedBanner(
                            peerName: conn.activeSession!.peerName),
                      const SizedBox(height: 24),
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
                                      const Color(0xFFCE93D8).withOpacity(0.12),
                                ),
                                child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: Color(0xFFCE93D8),
                                    size: 40),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Messages',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                conn.hasActiveSession
                                    ? 'Coming in Phase 3 — real-time\nchat with ${conn.activeSession!.peerName}.'
                                    : 'Connect to a device first to send messages.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              _FeatureChip(label: 'Real-time messaging'),
                              const SizedBox(height: 8),
                              _FeatureChip(label: 'Send files in chat'),
                              const SizedBox(height: 8),
                              _FeatureChip(label: 'Message history'),
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
  final String peerName;
  const _ConnectedBanner({required this.peerName});

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
            'Connected to $peerName',
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
