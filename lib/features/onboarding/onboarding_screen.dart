import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart' as t;
import 'onboarding_notifier.dart';
import 'onboarding_state.dart';

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
      backgroundColor: charcoal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: switch (state.step) {
            OnboardingStep.phoneEntry => const _PhoneEntryStep(),
            OnboardingStep.otpVerification => const _OtpVerificationStep(),
            OnboardingStep.contactsPermission =>
              const _ContactsPermissionStep(),
          },
        ),
      ),
    );
  }
}

// ============================================================
// Phone Entry (no back button — this is the first step)
// ============================================================
class _PhoneEntryStep extends ConsumerStatefulWidget {
  const _PhoneEntryStep();

  @override
  ConsumerState<_PhoneEntryStep> createState() => _PhoneEntryStepState();
}

class _PhoneEntryStepState extends ConsumerState<_PhoneEntryStep> {
  final _controller = TextEditingController();
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'US');

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
        Text(
          'roger',
          style: t.wordmarkLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        InternationalPhoneNumberInput(
          onInputChanged: (PhoneNumber number) {
            _phoneNumber = number;
          },
          selectorConfig: const SelectorConfig(
            selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
            useBottomSheetSafeArea: true,
            leadingPadding: 12,
          ),
          textFieldController: _controller,
          initialValue: _phoneNumber,
          keyboardType: TextInputType.phone,
          textStyle: t.inputText,
          selectorTextStyle: t.inputText,
          inputDecoration: InputDecoration(
            hintText: 'Phone number',
            hintStyle: t.hintText,
            enabledBorder: t.inputBorderEnabled,
            focusedBorder: t.inputBorderFocused,
          ),
          cursorColor: warmWhite,
        ),
        _ErrorText(state.error),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Continue',
          isLoading: state.isLoading,
          onPressed: () {
            ref.read(onboardingProvider.notifier).sendOtp(
                  _phoneNumber.phoneNumber ?? '',
                );
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
class _OtpVerificationStep extends ConsumerStatefulWidget {
  const _OtpVerificationStep();

  @override
  ConsumerState<_OtpVerificationStep> createState() =>
      _OtpVerificationStepState();
}

class _OtpVerificationStepState extends ConsumerState<_OtpVerificationStep> {
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
          'Enter verification code',
          style: t.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          state.phoneNumber,
          style: t.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          style: t.inputText,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: t.hintText,
            enabledBorder: t.inputBorderEnabled,
            focusedBorder: t.inputBorderFocused,
          ),
        ),
        _ErrorText(state.error),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Verify',
          isLoading: state.isLoading,
          onPressed: () {
            notifier.verifyOtp(_controller.text);
          },
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: state.isLoading ? null : notifier.resendOtp,
          child: const Text(
            'Resend code',
            style: t.buttonLabel,
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
          style: t.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Allow contacts access to find friends on roger. '
          'Rest assured, unecrypted numbers never leave your phone.',
          style: t.bodySubdued,
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
            style: t.buttonLabel,
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
        icon: const Icon(Icons.arrow_back, color: warmWhite),
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
        style: t.errorText,
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
          backgroundColor: charcoal2,
          foregroundColor: warmWhite,
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
                  color: warmWhite,
                ),
              )
            : Text(label, style: t.bodyText),
      ),
    );
  }
}
