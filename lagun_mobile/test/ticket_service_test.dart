import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/services/ticket_service.dart';

class FakeTicketRepository implements TicketRepository {
  @override
  String? currentUserId = 'user-a';

  List<Map<String, dynamic>> records = [];

  Map<String, dynamic>? inserted;
  String? requestedUserId;

  int insertCount = 0;

  Object? fetchError;
  Object? insertError;

  Completer<void>? insertBarrier;

  @override
  Future<List<Map<String, dynamic>>> fetchTickets(String userId) async {
    requestedUserId = userId;

    if (fetchError != null) {
      throw fetchError!;
    }

    return records;
  }

  @override
  Future<void> insertTicket(Map<String, dynamic> ticket) async {
    insertCount++;
    inserted = ticket;

    if (insertBarrier != null) {
      await insertBarrier!.future;
    }

    if (insertError != null) {
      throw insertError!;
    }

    records.add(ticket);
  }
}

void main() {
  late FakeTicketRepository fake;
  late TicketService service;

  setUp(() {
    fake = FakeTicketRepository();
    service = TicketService(fake);
  });

  Future<void> createValidTicket() {
    return service.createTicket(
      title: 'Falla app',
      description: 'No puedo abrir noticias',
      category: 'app',
    );
  }

  group('White Box - Lectura de REPORTES', () {
    test('WB-18: rechaza lectura sin sesión', () async {
      fake.currentUserId = null;

      await expectLater(
        service.loadTickets(),
        throwsA(isA<TicketNotAuthenticated>()),
      );

      expect(fake.requestedUserId, isNull);
    });

    test('WB-19: consulta con ID del usuario', () async {
      fake.records = [
        {'id': 't1', 'user_id': 'user-a'},
      ];

      final result = await service.loadTickets();

      expect(fake.requestedUserId, 'user-a');
      expect(result.single['id'], 't1');
    });

    test('WB-20: permite una lista vacía', () async {
      final result = await service.loadTickets();

      expect(result, isEmpty);
    });

    test('WB-21: propaga errores de lectura', () async {
      fake.fetchError = StateError('Fallo de red');

      await expectLater(service.loadTickets(), throwsStateError);
    });
  });

  group('White Box - Escritura de REPORTES', () {
    test('WB-22: inserta datos correctos', () async {
      await service.createTicket(
        title: '  Error de app  ',
        description: '  No aparecen los reportes  ',
        category: 'content',
      );

      expect(fake.inserted, {
        'user_id': 'user-a',
        'title': 'Error de app',
        'description': 'No aparecen los reportes',
        'category': 'content',
      });

      expect(fake.insertCount, 1);
    });

    test('WB-23: rechaza asunto corto', () async {
      await expectLater(
        service.createTicket(
          title: 'abc',
          description: 'Descripción larga',
          category: 'app',
        ),
        throwsA(isA<TicketValidationException>()),
      );

      expect(fake.insertCount, 0);
    });

    test('WB-24: rechaza descripción corta', () async {
      await expectLater(
        service.createTicket(
          title: 'Asunto',
          description: 'corta',
          category: 'app',
        ),
        throwsA(isA<TicketValidationException>()),
      );

      expect(fake.insertCount, 0);
    });

    test('WB-25: rechaza categoría inválida', () async {
      await expectLater(
        service.createTicket(
          title: 'Asunto',
          description: 'Descripción válida',
          category: 'admin',
        ),
        throwsA(isA<TicketValidationException>()),
      );

      expect(fake.insertCount, 0);
    });

    test('WB-26: rechaza escritura sin sesión', () async {
      fake.currentUserId = null;

      await expectLater(
        createValidTicket(),
        throwsA(isA<TicketNotAuthenticated>()),
      );

      expect(fake.insertCount, 0);
    });

    test('WB-27: error libera bandera', () async {
      fake.insertError = StateError('Servicio no disponible');

      await expectLater(createValidTicket(), throwsStateError);

      expect(service.isSubmitting, isFalse);
      expect(fake.insertCount, 1);
    });

    test('WB-28: impide envíos simultáneos', () async {
      fake.insertBarrier = Completer<void>();

      final first = createValidTicket();

      expect(service.isSubmitting, isTrue);

      await expectLater(
        createValidTicket(),
        throwsA(isA<TicketSubmissionInProgress>()),
      );

      expect(fake.insertCount, 1);

      fake.insertBarrier!.complete();

      await first;

      expect(service.isSubmitting, isFalse);
    });

    test('WB-29: permite reintentar tras error', () async {
      fake.insertError = StateError('Temporal');

      await expectLater(createValidTicket(), throwsStateError);

      fake.insertError = null;

      await createValidTicket();

      expect(fake.insertCount, 2);
      expect(fake.records, hasLength(1));
    });

    test('WB-30: libera bandera tras éxito', () async {
      await createValidTicket();

      expect(service.isSubmitting, isFalse);
    });
  });
}
