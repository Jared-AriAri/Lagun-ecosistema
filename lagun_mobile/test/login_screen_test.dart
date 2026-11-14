import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/auth/login_screen.dart';
import 'package:lagun_mobile/auth/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<void> fillLogin(
    WidgetTester tester, {
    String email = 'usuario@lagun.test',
    String password = 'ClaveSegura123',
  }) async {
    await tester.enterText(find.byType(TextField).at(0), email);

    await tester.enterText(find.byType(TextField).at(1), password);
  }

  Future<void> pressLogin(WidgetTester tester) async {
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();
  }

  group('White Box - Inicio de sesión', () {
    testWidgets('WB-58: el formulario muestra los campos requeridos', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });

    testWidgets('WB-59: la contraseña permanece oculta', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      final passwordField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );

      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('WB-60: permite navegar al registro', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));

      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('REGISTRARSE'), findsOneWidget);
    });

    testWidgets('WB-61: permite regresar desde registro al inicio de sesión', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
    });

    testWidgets('WB-62: autenticación correcta y navegación', (tester) async {
      var calls = 0;
      String? receivedEmail;
      String? receivedPassword;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authenticator:
                ({required String email, required String password}) async {
                  calls++;
                  receivedEmail = email;
                  receivedPassword = password;
                  return true;
                },
            authenticatedHomeBuilder: (_) => const Scaffold(
              body: Center(child: Text('INICIO CORRECTO DE PRUEBA')),
            ),
          ),
        ),
      );

      await fillLogin(tester, email: '  usuario@lagun.test  ');

      await pressLogin(tester);
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(receivedEmail, 'usuario@lagun.test');
      expect(receivedPassword, 'ClaveSegura123');

      expect(find.text('INICIO CORRECTO DE PRUEBA'), findsOneWidget);

      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('WB-63: credenciales rechazadas por Supabase', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authenticator:
                ({required String email, required String password}) async {
                  throw const AuthException('Credenciales incorrectas');
                },
          ),
        ),
      );

      await fillLogin(tester);
      await pressLogin(tester);
      await tester.pumpAndSettle();

      expect(find.text('Credenciales incorrectas'), findsOneWidget);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('WB-64: maneja un error inesperado de conexión', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authenticator:
                ({required String email, required String password}) async {
                  throw Exception('Sin conexión de prueba');
                },
          ),
        ),
      );

      await fillLogin(tester);
      await pressLogin(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('ERROR DE CONEXIÓN O CREDENCIALES INVÁLIDAS.'),
        findsOneWidget,
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('WB-65: rechaza autenticación sin sesión válida', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authenticator:
                ({required String email, required String password}) async {
                  return false;
                },
          ),
        ),
      );

      await fillLogin(tester);
      await pressLogin(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('ERROR DE CONEXIÓN O CREDENCIALES INVÁLIDAS.'),
        findsOneWidget,
      );

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('WB-66: bloquea envíos mientras autentica', (tester) async {
      final pendingAuthentication = Completer<bool>();
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authenticator: ({required String email, required String password}) {
              calls++;
              return pendingAuthentication.future;
            },
          ),
        ),
      );

      await fillLogin(tester);
      await pressLogin(tester);

      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final loginButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );

      expect(loginButton.onPressed, isNull);

      final registerButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('¿No tienes cuenta? Regístrate'),
          matching: find.byType(TextButton),
        ),
      );

      expect(registerButton.onPressed, isNull);

      pendingAuthentication.complete(false);

      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(
        find.text('ERROR DE CONEXIÓN O CREDENCIALES INVÁLIDAS.'),
        findsOneWidget,
      );
    });
  });
}
