import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/auth/email_confirmation_screen.dart';
import 'package:lagun_mobile/auth/login_screen.dart';

void main() {
  group('White Box - Confirmación de correo', () {
    testWidgets('WB-55: muestra el correo del usuario', (tester) async {
      const email = 'prueba@lagun.test';

      await tester.pumpWidget(
        const MaterialApp(home: EmailConfirmationScreen(email: email)),
      );

      expect(find.text('// VERIFICACIÓN DE CORREO //'), findsOneWidget);

      expect(find.text('¡Cuenta creada con éxito!'), findsOneWidget);

      expect(find.textContaining(email), findsOneWidget);
    });

    testWidgets('WB-56: muestra el botón de inicio de sesión', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmailConfirmationScreen(email: 'usuario@lagun.test'),
        ),
      );

      expect(find.text('IR A INICIAR SESIÓN'), findsOneWidget);

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('WB-57: navega correctamente a LoginScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmailConfirmationScreen(email: 'usuario@lagun.test'),
        ),
      );

      await tester.tap(find.text('IR A INICIAR SESIÓN'));

      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      expect(find.text('INICIAR SESIÓN'), findsOneWidget);

      expect(find.byType(EmailConfirmationScreen), findsNothing);
    });
  });
}
