import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingNotifier _notifier;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _notifier = OnboardingNotifier(
      authService: AuthService(),
      contactsService: ContactsService(),
    );

    // Listen for magic link callback
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _notifier.onAuthStateChanged().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
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
            OnboardingStep.emailEntry => _EmailEntryStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.awaitingEmail => _AwaitingEmailStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.phoneNumber => _PhoneNumberStep(
                notifier: _notifier,
                onChanged: _rebuild,
              ),
            OnboardingStep.displayName => _DisplayNameStep(
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
// Email Entry (no back button — this is the first step)
// ============================================================
class _EmailEntryStep extends StatefulWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _EmailEntryStep({required this.notifier, required this.onChanged});

  @override
  State<_EmailEntryStep> createState() => _EmailEntryStepState();
}

class _EmailEntryStepState extends State<_EmailEntryStep> {
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
        _ErrorText(state.error),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Continue',
          isLoading: state.isLoading,
          onPressed: () async {
            await widget.notifier.sendMagicLink(_controller.text);
            widget.onChanged();
          },
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Awaiting Email (magic link sent, waiting for user to tap it)
// ============================================================
class _AwaitingEmailStep extends StatelessWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _AwaitingEmailStep({
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
          'Check your email',
          style: TextStyle(color: _warmWhite, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          state.email,
          style: const TextStyle(color: _warmWhite, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Tap the link in the email to continue.\nOpen it on this device.',
          style: TextStyle(
            color: _warmWhite.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        _ErrorText(state.error),
        if (state.isLoading) ...[
          const SizedBox(height: 32),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _warmWhite,
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () async {
                  await notifier.resendMagicLink();
                  onChanged();
                },
          child: const Text(
            'Resend email',
            style: TextStyle(color: _warmWhite),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ============================================================
// Phone Number
// ============================================================
class _PhoneNumberStep extends StatefulWidget {
  final OnboardingNotifier notifier;
  final VoidCallback onChanged;

  const _PhoneNumberStep({required this.notifier, required this.onChanged});

  @override
  State<_PhoneNumberStep> createState() => _PhoneNumberStepState();
}

class _PhoneNumberStepState extends State<_PhoneNumberStep> {
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
          'Your phone number',
          style: TextStyle(color: _warmWhite, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your phone number helps friends find you on roger.',
          style: TextStyle(
            color: _warmWhite.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
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
          label: 'Continue',
          isLoading: state.isLoading,
          onPressed: () async {
            await widget.notifier.submitPhoneNumber(_controller.text);
            widget.onChanged();
          },
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
