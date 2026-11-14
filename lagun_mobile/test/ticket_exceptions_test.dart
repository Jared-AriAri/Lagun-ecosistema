import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/services/ticket_service.dart';

void main() {
  group('WB-52 a WB-54: presentación de errores de REPORTES', () {
    test('WB-52: error de autenticación presenta mensaje esperado', () {
      expect(const TicketNotAuthenticated().toString(), 'Debes iniciar sesión');
    });
    test('WB-53: error de validación conserva el detalle', () {
      expect(const TicketValidationException('Categoría no válida').toString(), 'Categoría no válida');
    });
    test('WB-54: envío simultáneo presenta mensaje esperado', () {
      expect(const TicketSubmissionInProgress().toString(), 'Ya se está enviando un ticket');
    });
  });
}
