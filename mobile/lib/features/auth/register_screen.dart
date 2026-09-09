import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// `flutter_riverpod` exports its own `Consumer` widget, which clashes with
// our domain `Consumer` model — hidden the same way
// `features/my_places/my_places_screen.dart` does.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;

import '../../core/theme/app_theme.dart';
import '../../data/connection_mode.dart';
import '../../data/providers.dart';

/// Real registration screen (`docs/flutter-vs-nextjs-gap-report.md`, Tarea
/// 4) — replaces the "Registro no disponible en este MVP" mock snackbar that
/// used to live on `MyPlacesScreen`'s "¿No tenés cuenta? Registrate" link.
///
/// No DNI field on purpose: per `openspec/changes/fudo-consumers-mvp/
/// design.md` (Decisión 1) and the backend fix in commit `1cdb20e`, the DNI
/// is loaded by the waiter at checkout in the physical restaurant, not
/// self-reported by the consumer at sign-up — `AuthRepository.register()`'s
/// `dni` parameter is optional exactly so this screen can leave it unset
/// (see that class's doc comment for why an empty string wouldn't have been
/// equivalent).
///
/// Same [ConnectionMode] split as `MyPlacesScreen`'s login form:
/// - [ConnectionMode.local] (the default, and what `flutter test` runs
///   under unless a test overrides it): 100% fake — filling in the required
///   fields and submitting just flips [isLoggedInProvider] to `true`, no
///   backend call, matching the existing fake-login philosophy for this MVP.
/// - [ConnectionMode.remote]: a real `AuthRepository.register()` call, with
///   real loading/error handling for a 422 (duplicate email, password
///   mismatch, etc.) — same error-parsing shape as
///   `features/gifting/gifting_screen.dart`'s `_remoteCreateGiftErrorMessage`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  /// `true` while a real [ConnectionMode.remote] registration request is in
  /// flight. Always `false` in [ConnectionMode.local] — that path never
  /// awaits anything, same as `my_places_screen.dart`'s login flow.
  bool _isSubmitting = false;

  /// Set when a real remote registration attempt fails — shown under the
  /// form, cleared on the next submit attempt. Always `null` in
  /// [ConnectionMode.local].
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final connectionMode = ref.read(connectionModeProvider);
    if (connectionMode == ConnectionMode.local) {
      // Matches the existing fake login: no backend to register against in
      // this mode, so a valid-looking form just logs the user in and pops
      // back to whatever pushed this screen (usually `MyPlacesScreen`,
      // which then rebuilds into its logged-in view).
      ref.read(isLoggedInProvider.notifier).logIn();
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final phone = _phoneController.text.trim();
      await ref
          .read(authRepositoryProvider)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _passwordConfirmationController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: phone.isEmpty ? null : phone,
          );
      // Same reasoning as `my_places_screen.dart`'s login flow: without
      // this, the profile screen would keep showing a stale/null consumer
      // after a successful registration.
      ref.invalidate(currentConsumerProvider);
      if (!mounted) return;
      ref.read(isLoggedInProvider.notifier).logIn();
      Navigator.of(context).pop();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _remoteRegisterErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'No pudimos conectarnos. Revisá tu conexión.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Reads the backend's `{"errors": {...}}` body on a 422 (per the
  /// confirmed `POST /registrations` contract documented on
  /// `AuthRepository`) into a single line; falls back to a generic
  /// connectivity message for anything else — same shape as
  /// `gifting_screen.dart`'s `_remoteCreateGiftErrorMessage`.
  String _remoteRegisterErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        return errors.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', ');
      }
    }
    return 'No pudimos conectarnos. Revisá tu conexión.';
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    if (!value!.contains('@')) return 'Ingresá un email válido';
    return null;
  }

  String? _passwordValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    if (value!.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  String? _passwordConfirmationValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Creá tu cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sumate a Fudo', style: AppTheme.headline),
                const SizedBox(height: 8),
                Text(
                  'Guardá tus lugares favoritos, sumá sellos y mandá gift '
                  'cards a tus amigos.',
                  style: AppTheme.bodySecondary,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey('registerFirstNameField'),
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('registerLastNameField'),
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('registerEmailField'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _emailValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('registerPhoneField'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('registerPasswordField'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: _passwordValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('registerPasswordConfirmationField'),
                  controller: _passwordConfirmationController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Repetí la contraseña',
                  ),
                  validator: _passwordConfirmationValidator,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('registerSubmitButton'),
                  onPressed: _isSubmitting ? null : _onSubmitPressed,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    key: const ValueKey('registerErrorMessage'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
