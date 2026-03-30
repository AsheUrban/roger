import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/contacts_service.dart';
import 'onboarding_notifier.dart';
import 'onboarding_state.dart';

// Spec colors
const _charcoal = Color(0xFF1E1D18);
const _charcoal2 = Color(0xFF2E2D26);
const _warmWhite = Color(0xFFFAFAF5);
// Error text: warm white at 70% — salmon is reserved for camera actions only
const _errorColor = Color(0xB3FAFAF5);

// Avatar colors: background → foreground pairs from spec section 4.
// Verify visually on emulator — hex values may need tuning.
const _avatarColorMap = {
  'Deep Red': (Color(0xFF2E0A0A), Color(0xFFFF8A80)),
  'Rust': (Color(0xFF7A3B2E), Color(0xFFFFB8A0)),
  'Deep Ember': (Color(0xFF3D1500), Color(0xFFFF6B4E)),
  'Burnt Orange': (Color(0xFF4A2800), Color(0xFFFFB347)),
  'Salmon': (Color(0xFFFF6B4E), Color(0xFFFFF0ED)),
  'Rose': (Color(0xFFFF5E7A), Color(0xFFFFE8EE)),
  'Olive': (Color(0xFF595900), Color(0xFFE8E600)),
  'Cornflower': (Color(0xFF6395EE), Color(0xFFEDD4FA)),
  'Charcoal': (Color(0xFF1E1D18), Color(0xFFFAFAF5)),
};

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = OnboardingNotifier(
      authService: AuthService(),
      contactsService: ContactsService(),
    );
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = _notifier.state;

    // Navigate away when onboarding completes
    if (state.onboardingComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/search');
      });
    }

    return Scaffold(
      backgroundColor: _charcoal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: switch (state.step) {
            OnboardingStep.phoneEntry => _PhoneEntryStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.otpVerification => _OtpVerificationStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.displayName => _DisplayNameStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.avatarColor => _AvatarColorStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.recoveryEmail => _RecoveryEmailStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.contactsPermission => _ContactsPermissionStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
          },
        ),
      ),
    );
  }
}

// ============================================================
// Phone Entry (no back button — this is the first step)
// ============================================================
class _PhoneEntryStep extends StatefulWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _PhoneEntryStep({required this.notifier, required this.onChanged});

  @override
  State<_PhoneEntryStep> createState() => _PhoneEntryStepState();
}

class _PhoneEntryStepState extends State<_PhoneEntryStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.notifier.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Text(
          'roger',
          style: TextStyle(
            color: _warmWhite,
            fontSize: 40,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: _warmWhite),
          decoration: InputDecoration(
            hintText: 'Phone number',
            hintStyle: TextStyle(color: _warmWhite.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite),
            ),
          ),
        ),
        _ErrorText(state.error),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Send code',
          isLoading: state.isLoading,
          onPressed: () async {
            await widget.notifier.submitPhoneNumber(_controller.text.trim());
            widget.onChanged();
          },
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// OTP Verification
// ============================================================
class _OtpVerificationStep extends StatefulWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _OtpVerificationStep({
    required this.notifier,
    required this.onChanged,
  });

  @override
  State<_OtpVerificationStep> createState() => _OtpVerificationStepState();
}

class _OtpVerificationStepState extends State<_OtpVerificationStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.notifier.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(
          onPressed: () {
            widget.notifier.goBack();
            widget.onChanged();
          },
        ),
        const Spacer(),
        Text(
          'Enter the code sent to\n${state.phoneNumber}',
          style: const TextStyle(color: _warmWhite, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _warmWhite,
            fontSize: 28,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(color: _warmWhite.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite),
            ),
          ),
        ),
        _ErrorText(state.error),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Verify',
          isLoading: state.isLoading,
          onPressed: () async {
            await widget.notifier.verifyOtp(_controller.text.trim());
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: state.canResendOtp
              ? () async {
                  await widget.notifier.resendOtp();
                  widget.onChanged();
                }
              : null,
          child: Text(
            state.canResendOtp ? 'Resend code' : 'Resend available shortly',
            style: TextStyle(
              color: state.canResendOtp
                  ? _warmWhite
                  : _warmWhite.withValues(alpha: 0.3),
            ),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Display Name
// ============================================================
class _DisplayNameStep extends StatefulWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _DisplayNameStep({required this.notifier, required this.onChanged});

  @override
  State<_DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends State<_DisplayNameStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.notifier.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(
          onPressed: () {
            widget.notifier.goBack();
            widget.onChanged();
          },
        ),
        const Spacer(),
        const Text(
          'What should people\ncall you?',
          style: TextStyle(color: _warmWhite, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          maxLength: 50,
          style: const TextStyle(color: _warmWhite),
          decoration: InputDecoration(
            hintText: 'Display name',
            hintStyle: TextStyle(color: _warmWhite.withValues(alpha: 0.5)),
            counterStyle: TextStyle(color: _warmWhite.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite),
            ),
          ),
        ),
        _ErrorText(state.error),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Continue',
          onPressed: () {
            widget.notifier.setDisplayName(_controller.text);
            widget.onChanged();
          },
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Avatar Color (browse freely, Continue button to advance)
// ============================================================
class _AvatarColorStep extends StatelessWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _AvatarColorStep({required this.notifier, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final state = notifier.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(
          onPressed: () {
            notifier.goBack();
            onChanged();
          },
        ),
        const Spacer(),
        const Text(
          'Pick your color',
          style: TextStyle(color: _warmWhite, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Preview avatar
        Center(
          child: _AvatarPreview(
            colorName: state.avatarColor,
            initial: state.displayName.isNotEmpty
                ? state.displayName[0].toUpperCase()
                : '?',
            size: 80,
          ),
        ),
        const SizedBox(height: 32),
        // Color grid — tapping previews, does not advance
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: avatarColors.map((name) {
            final colors = _avatarColorMap[name]!;
            final isSelected = state.avatarColor == name;
            return GestureDetector(
              onTap: () {
                notifier.setAvatarColor(name);
                onChanged();
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.$1,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: _warmWhite, width: 3)
                      : null,
                ),
                child: Center(
                  child: Text(
                    state.displayName.isNotEmpty
                        ? state.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: colors.$2, fontSize: 22),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        _PrimaryButton(
          label: 'Continue',
          onPressed: () {
            notifier.confirmAvatarColor();
            onChanged();
          },
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Recovery Email
// ============================================================
class _RecoveryEmailStep extends StatefulWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _RecoveryEmailStep({required this.notifier, required this.onChanged});

  @override
  State<_RecoveryEmailStep> createState() => _RecoveryEmailStepState();
}

class _RecoveryEmailStepState extends State<_RecoveryEmailStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(
          onPressed: () {
            widget.notifier.goBack();
            widget.onChanged();
          },
        ),
        const Spacer(),
        const Text(
          'Recovery email',
          style: TextStyle(color: _warmWhite, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Without a recovery email, your account cannot be '
          'recovered if you change or lose your phone number.',
          style: TextStyle(
            color: _warmWhite.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: _warmWhite),
          decoration: InputDecoration(
            hintText: 'Email address',
            hintStyle: TextStyle(color: _warmWhite.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _warmWhite),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Save email',
          onPressed: () {
            widget.notifier.setRecoveryEmail(_controller.text.trim());
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            widget.notifier.skipRecoveryEmail();
            widget.onChanged();
          },
          child: const Text(
            'Skip for now',
            style: TextStyle(color: _warmWhite),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Contacts Permission
// ============================================================
class _ContactsPermissionStep extends StatelessWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _ContactsPermissionStep({
    required this.notifier,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final state = notifier.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(
          onPressed: () {
            notifier.goBack();
            onChanged();
          },
        ),
        const Spacer(),
        const Text(
          'Find your people',
          style: TextStyle(color: _warmWhite, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Allow contacts access to find friends on roger. '
          'Your contacts are hashed on-device — raw numbers never leave your phone.',
          style: TextStyle(
            color: _warmWhite.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _PrimaryButton(
          label: 'Allow contacts',
          isLoading: state.isLoading,
          onPressed: () async {
            await notifier.requestContactsPermission();
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () async {
                  await notifier.skipContactsPermission();
                  onChanged();
                },
          child: const Text(
            'Not now',
            style: TextStyle(color: _warmWhite),
          ),
        ),
        _ErrorText(state.error),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Shared widgets
// ============================================================
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back, color: _warmWhite),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String? error;

  const _ErrorText(this.error);

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        error!,
        style: const TextStyle(color: _errorColor, fontSize: 14),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _charcoal2,
          foregroundColor: _warmWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _warmWhite,
                ),
              )
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String colorName;
  final String initial;
  final double size;

  const _AvatarPreview({
    required this.colorName,
    required this.initial,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _avatarColorMap[colorName] ?? (_charcoal2, _warmWhite);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.$1,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colors.$2,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
