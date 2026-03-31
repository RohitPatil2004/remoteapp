import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/auth_widgets.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  // Password strength
  double _passStrength = 0;
  String _passHint = '';

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnim = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    _passCtrl.addListener(_checkStrength);
  }

  void _checkStrength() {
    final p = _passCtrl.text;
    double s = 0;
    String hint = '';
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) s += 0.25;

    if (s <= 0.25)
      hint = 'Weak';
    else if (s <= 0.5)
      hint = 'Fair';
    else if (s <= 0.75)
      hint = 'Good';
    else
      hint = 'Strong';

    setState(() {
      _passStrength = s;
      _passHint = hint;
    });
  }

  Color get _strengthColor {
    if (_passStrength <= 0.25) return AppTheme.error;
    if (_passStrength <= 0.5) return Colors.orange;
    if (_passStrength <= 0.75) return Colors.yellow;
    return AppTheme.success;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signup(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 700;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? (w - 480) / 2 : 24,
                vertical: 32,
              ),
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, child) => FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(position: _slideAnim, child: child),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 36),
                    Text(
                      'Create account',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get your unique 12-digit device code',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 36),
                    GlassCard(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Error banner
                            if (auth.error != null) ...[
                              ErrorBanner(
                                message: auth.error!,
                                onDismiss: () => auth.clearError(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Full name
                            TextFormField(
                              controller: _nameCtrl,
                              style:
                                  const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    color: AppTheme.textHint, size: 20),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Enter your name';
                                if (v.trim().length < 2)
                                  return 'Name too short';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style:
                                  const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(Icons.mail_outline_rounded,
                                    color: AppTheme.textHint, size: 20),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Enter your email';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                    .hasMatch(v)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              style:
                                  const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppTheme.textHint,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.textHint,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Enter a password';
                                if (v.length < 8)
                                  return 'At least 8 characters required';
                                return null;
                              },
                            ),

                            // Password strength bar
                            if (_passCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _passStrength,
                                        minHeight: 4,
                                        backgroundColor: AppTheme.glassWhite,
                                        valueColor: AlwaysStoppedAnimation(
                                            _strengthColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _passHint,
                                    style: TextStyle(
                                      color: _strengthColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Confirm password
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscureConfirm,
                              style:
                                  const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Confirm password',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppTheme.textHint,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.textHint,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Confirm your password';
                                if (v != _passCtrl.text)
                                  return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            GlowButton(
                              label: 'Create Account',
                              isLoading: auth.isLoading,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                                context, '/login'),
                            child: Text(
                              'Sign in',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
