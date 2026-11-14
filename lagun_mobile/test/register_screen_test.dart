import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/auth/register_screen.dart';
import 'package:lagun_mobile/auth/email_confirmation_screen.dart';

void main() {
  Future<void> fillRegister(
    WidgetTester tester, {
    String name = 'Usuario Prueba',
    String email = 'usuario@lagun.test',
    String password = 'ClaveSegura123',
  }) async {
    await tester.enterText(find.byType(TextField).at(0), name);

    await tester.enterText(find.byType(TextField).at(1), email);

    await tester.enterText(find.byType(TextField).at(2), password);
  }

  Future<void> pressRegister(WidgetTester tester) async {
    await tester.tap(find.text('REGISTRARSE'));
    await tester.pump();
  }

  group('White Box - Registro de usuarios', () {
    testWidgets('WB-67: registro exitoso con sesión activa', (tester) async {
      var registerCalls = 0;
      var profileCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            registerAccount:
                ({required String email, required String password}) async {
                  registerCalls++;

                  return const RegistrationResult(
                    userId: 'usuario-67',
                    hasSession: true,
                  );
                },
            saveProfile:
                ({required String userId, required String fullName}) async {
                  profileCalls++;
                  expect(userId, 'usuario-67');
                },
            authenticatedHomeBuilder: (_) => const Scaffold(
              body: Center(child: Text('INICIO REGISTRO CORRECTO')),
            ),
          ),
        ),
      );

      await fillRegister(tester);
      await pressRegister(tester);
      await tester.pumpAndSettle();

      expect(registerCalls, 1);
      expect(profileCalls, 1);

      expect(find.text('INICIO REGISTRO CORRECTO'), findsOneWidget);

      expect(find.byType(RegisterScreen), findsNothing);
    });

    testWidgets('WB-68: registro sin sesión solicita confirmar correo', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            registerAccount:
                ({required String email, required String password}) async {
                  return const RegistrationResult(
                    userId: 'usuario-68',
                    hasSession: false,
                  );
                },
            saveProfile:
                ({required String userId, required String fullName}) async {},
          ),
        ),
      );

      await fillRegister(tester, email: 'confirmacion@lagun.test');

      await pressRegister(tester);
      await tester.pumpAndSettle();

      expect(find.byType(EmailConfirmationScreen), findsOneWidget);

      expect(find.textContaining('confirmacion@lagun.test'), findsOneWidget);

      expect(find.byType(RegisterScreen), findsNothing);
    });

    testWidgets('WB-69: error de registro muestra mensaje', (tester) async {
      var profileCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            registerAccount:
                ({required String email, required String password}) async {
                  throw Exception('Registro rechazado de prueba');
                },
            saveProfile:
                ({required String userId, required String fullName}) async {
                  profileCalls++;
                },
          ),
        ),
      );

      await fillRegister(tester);
      await pressRegister(tester);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Registro rechazado de prueba'),
        findsOneWidget,
      );

      expect(profileCalls, 0);
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('WB-70: respuesta sin usuario impide guardar perfil', (
      tester,
    ) async {
      var profileCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            registerAccount:
                ({required String email, required String password}) async {
                  return const RegistrationResult(
                    userId: null,
                    hasSession: false,
                  );
                },
            saveProfile:
                ({required String userId, required String fullName}) async {
                  profileCalls++;
                },
          ),
        ),
      );

      await fillRegister(tester);
      await pressRegister(tester);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('El registro no devolvió un usuario.'),
        findsOneWidget,
      );

      expect(profileCalls, 0);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('WB-71: bloquea registros mientras procesa solicitud', (
      tester,
    ) async {
      final pendingRegistration = Completer<RegistrationResult>();
      var registerCalls = 0;
      var profileCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            registerAccount:
                ({required String email, required String password}) {
                  registerCalls++;
                  return pendingRegistration.future;
                },
            saveProfile:
                ({required String userId, required String fullName}) async {
                  profileCalls++;
                },
          ),
        ),
      );

      await fillRegister(tester);
      await pressRegister(tester);

      expect(registerCalls, 1);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final registerButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );

      expect(registerButton.onPressed, isNull);

      final backButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('¿Ya tienes cuenta? Inicia sesión'),
          matching: find.byType(TextButton),
        ),
      );

      expect(backButton.onPressed, isNull);

      pendingRegistration.complete(
        const RegistrationResult(userId: null, hasSession: false),
      );

      await tester.pumpAndSettle();

      expect(registerCalls, 1);
      expect(profileCalls, 0);

      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(
        find.textContaining('El registro no devolvió un usuario.'),
        findsOneWidget,
      );
    });

    testWidgets('WB-72: envía datos correctos y guarda perfil', (tester) async {
      String? receivedEmail;
      String? receivedPassword;
      String? receivedUserId;
      String? receivedFullName;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            registerAccount:
                ({required String email, required String password}) async {
                  receivedEmail = email;
                  receivedPassword = password;

                  return const RegistrationResult(
                    userId: 'usuario-72',
                    hasSession: false,
                  );
                },
            saveProfile:
                ({required String userId, required String fullName}) async {
                  receivedUserId = userId;
                  receivedFullName = fullName;
                },
          ),
        ),
      );

      await fillRegister(
        tester,
        name: '  María González  ',
        email: '  maria@lagun.test  ',
        password: '  Clave123456  ',
      );

      await pressRegister(tester);
      await tester.pumpAndSettle();

      expect(receivedEmail, 'maria@lagun.test');
      expect(receivedPassword, 'Clave123456');
      expect(receivedUserId, 'usuario-72');
      expect(receivedFullName, 'María González');

      expect(find.byType(EmailConfirmationScreen), findsOneWidget);
    });
  });
}
