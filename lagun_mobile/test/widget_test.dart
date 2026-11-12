import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/auth/login_screen.dart';

void main() {
  group('WB-LAGUN - Validaciones de autenticación', () {
    Future<void> abrirLogin(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    }

    testWidgets('WB-01: muestra los campos de acceso', (tester) async {
      await abrirLogin(tester);

      expect(find.text('LAGUN'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });

    testWidgets('WB-02: rechaza ambos campos vacíos', (tester) async {
      await abrirLogin(tester);

      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('INGRESA TU CORREO Y CONTRASEÑA.'), findsOneWidget);
    });

    testWidgets('WB-03: rechaza correo vacío', (tester) async {
      await abrirLogin(tester);

      await tester.enterText(find.byType(TextField).at(1), 'Password123');

      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('INGRESA TU CORREO Y CONTRASEÑA.'), findsOneWidget);
    });

    testWidgets('WB-04: rechaza contraseña vacía', (tester) async {
      await abrirLogin(tester);

      await tester.enterText(find.byType(TextField).first, 'prueba@lagun.com');

      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('INGRESA TU CORREO Y CONTRASEÑA.'), findsOneWidget);
    });

    testWidgets('WB-05: rechaza correo con solo espacios', (tester) async {
      await abrirLogin(tester);

      await tester.enterText(find.byType(TextField).first, '   ');

      await tester.enterText(find.byType(TextField).at(1), 'Password123');

      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('INGRESA TU CORREO Y CONTRASEÑA.'), findsOneWidget);
    });
  });
}
