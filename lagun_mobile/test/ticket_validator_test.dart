import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/validators/ticket_validator.dart';

void main() {
  group('WB-REPORTES - Validación de asunto', () {
    test('WB-06: valor nulo', () {
      expect(TicketValidator.validateTitle(null), isNotNull);
    });

    test('WB-07: asunto vacío', () {
      expect(TicketValidator.validateTitle(''), isNotNull);
    });

    test('WB-08: cuatro caracteres', () {
      expect(TicketValidator.validateTitle('ABCD'), isNotNull);
    });

    test('WB-09: cinco caracteres exactos', () {
      expect(TicketValidator.validateTitle('ABCDE'), isNull);
    });

    test('WB-10: asunto con espacios', () {
      expect(TicketValidator.validateTitle('  ABC  '), isNotNull);
    });

    test('WB-11: asunto válido', () {
      expect(TicketValidator.validateTitle('Error en noticias'), isNull);
    });
  });

  group('WB-REPORTES - Validación de descripción', () {
    test('WB-12: valor nulo', () {
      expect(TicketValidator.validateDescription(null), isNotNull);
    });

    test('WB-13: descripción vacía', () {
      expect(TicketValidator.validateDescription(''), isNotNull);
    });

    test('WB-14: nueve caracteres', () {
      expect(TicketValidator.validateDescription('123456789'), isNotNull);
    });

    test('WB-15: diez caracteres exactos', () {
      expect(TicketValidator.validateDescription('1234567890'), isNull);
    });

    test('WB-16: espacios exteriores', () {
      expect(TicketValidator.validateDescription('  123456789  '), isNotNull);
    });

    test('WB-17: descripción válida', () {
      expect(
        TicketValidator.validateDescription(
          'La aplicación no carga las noticias',
        ),
        isNull,
      );
    });
  });
}
