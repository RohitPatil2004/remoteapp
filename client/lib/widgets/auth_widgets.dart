import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: AppTheme.accent.withOpacity(0.7), width: 1.5),
            color: AppTheme.accentGlow,
          ),
          child:
              const Icon(Icons.lan_rounded, color: AppTheme.accent, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'RemoteApp',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accent,
                letterSpacing: 1,
              ),
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const ErrorBanner(
      {super.key, required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppTheme.error, size: 16),
          ),
        ],
      ),
    );
  }
}

class GlowButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const GlowButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppTheme.bgDark),
                ),
              )
            : Text(label),
      ),
    );
  }
}
