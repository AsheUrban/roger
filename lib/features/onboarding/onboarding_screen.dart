import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_notifier.dart';
import 'onboarding_state.dart';

// Spec colors
const _charcoal = Color(0xFF1E1D18);
const _charcoal2 = Color(0xFF2E2D26);
const _warmWhite = Color(0xFFFAFAF5);
// Error text: warm white at 70% — salmon is reserved for camera actions only
const _errorColor = Color(0xB3FAFAF5);

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    ref.listen<OnboardingState>(onboardingProvider, (prev, next) {
      if (next.onboardingComplete) {
        context.go('/search');
      }
    });

    return Scaffold(
      backgroundColor: _charcoal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: switch (state.step) {
            OnboardingStep.emailEntry => const _EmailEntryStep(),
            OnboardingStep.awaitingEmail => const _AwaitingEmailStep(),
            OnboardingStep.phoneNumber => const _PhoneNumberStep(),
            OnboardingStep.displayName => const _DisplayNameStep(),
            OnboardingStep.contactsPermission =>
              const _ContactsPermissionStep(),
          },
        ),
      ),
    );
  }
}

// ============================================================
// Email Entry (no back button — this is the first step)
// ============================================================
class _EmailEntryStep extends ConsumerStatefulWidget {
  const _EmailEntryStep();

  @override
  ConsumerState<_EmailEntryStep> createState() => _EmailEntryStepState();
}

class _EmailEntryStepState extends ConsumerState<_EmailEntryStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

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
          onPressed: () {
            ref.read(onboardingProvider.notifier).sendMagicLink(
                  _controller.text,
                );
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
class _AwaitingEmailStep extends ConsumerWidget {
  const _AwaitingEmailStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(onPressed: notifier.goBack),
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
          onPressed: state.isLoading ? null : notifier.resendMagicLink,
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
class _PhoneNumberStep extends ConsumerStatefulWidget {
  const _PhoneNumberStep();

  @override
  ConsumerState<_PhoneNumberStep> createState() => _PhoneNumberStepState();
}

class _PhoneNumberStepState extends ConsumerState<_PhoneNumberStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(onPressed: notifier.goBack),
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
          onPressed: () {
            notifier.submitPhoneNumber(_controller.text);
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
class _DisplayNameStep extends ConsumerStatefulWidget {
  const _DisplayNameStep();

  @override
  ConsumerState<_DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends ConsumerState<_DisplayNameStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(onPressed: notifier.goBack),
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
            notifier.setDisplayName(_controller.text);
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
class _ContactsPermissionStep extends ConsumerWidget {
  const _ContactsPermissionStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(onPressed: notifier.goBack),
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
          onPressed: notifier.requestContactsPermission,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading ? null : notifier.skipContactsPermission,
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
