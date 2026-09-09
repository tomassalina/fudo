// Widget tests for `RegisterScreen` (Tarea 4 — see
// `docs/flutter-vs-nextjs-gap-report.md`).
//
// Covers the fake `ConnectionMode.local` path: form validation (required
// fields, email shape, password length/match) and the fake instant
// "registration" that logs the user in and pops the screen, matching the
// existing fake-login philosophy in `my_places_screen.dart`. The real
// `ConnectionMode.remote` path against `AuthRepository.register()` is
// exercised live in `test/features/my_places_screen_remote_login_test.dart`'s
// sibling for login — this file stays offline/deterministic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/auth/register_screen.dart';

void main() {
  Future<void> pumpRegisterScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('registerFirstNameField')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registerLastNameField')),
      'Lovelace',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registerEmailField')),
      'ada@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registerPasswordField')),
      'Demo1234',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registerPasswordConfirmationField')),
      'Demo1234',
    );
  }

  testWidgets('renders every field and no DNI field', (tester) async {
    await pumpRegisterScreen(tester);

    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Apellido'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Teléfono (opcional)'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Repetí la contraseña'), findsOneWidget);
    // Per design.md Decisión 1: DNI is loaded by the waiter at checkout,
    // never asked for at self-registration.
    expect(find.textContaining('DNI'), findsNothing);
  });

  testWidgets('rejects submit with empty required fields', (tester) async {
    await pumpRegisterScreen(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('registerSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Campo obligatorio'), findsWidgets);
    // Still on the register screen — no fake login happened.
    expect(find.byKey(const ValueKey('registerSubmitButton')), findsOneWidget);
  });

  testWidgets('rejects a password confirmation mismatch', (tester) async {
    await pumpRegisterScreen(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('registerPasswordConfirmationField')),
      'somethingElse1',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('registerSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('a valid form logs in (fake, local mode) and pops back', (
    tester,
  ) async {
    await pumpRegisterScreen(tester);
    await fillValidForm(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('registerSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('registerSubmitButton')));
    await tester.pumpAndSettle();

    // Popped back to the button that opened it.
    expect(find.text('open'), findsOneWidget);
    expect(find.byKey(const ValueKey('registerSubmitButton')), findsNothing);
  });

  testWidgets('a valid form flips isLoggedInProvider to true', (tester) async {
    late final ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterScreen(),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(container.read(isLoggedInProvider), isFalse);

    await fillValidForm(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('registerSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(container.read(isLoggedInProvider), isTrue);
  });
}
