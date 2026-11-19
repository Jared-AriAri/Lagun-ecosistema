import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/services/ticket_service.dart';
import 'package:uuid/uuid.dart';

class FakeTicketRepository implements TicketRepository {
  @override
  String? currentUserId = 'user-a';

  List<Map<String, dynamic>> records = [];

  Map<String, dynamic>? inserted;
  String? requestedUserId;

  final List<Map<String, dynamic>> insertAttempts = [];

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

    // Copia independiente para conservar la evidencia
    // de cada intento de inserción.
    inserted = Map<String, dynamic>.from(ticket);
    insertAttempts.add(Map<String, dynamic>.from(ticket));

    if (insertBarrier != null) {
      await insertBarrier!.future;
    }

    if (insertError != null) {
      throw insertError!;
    }

    records.add(Map<String, dynamic>.from(ticket));
  }
}

void main() {
  late FakeTicketRepository fake;
  late TicketService service;

  setUp(() {
    fake = FakeTicketRepository();
    service = TicketService(fake);
  });

  Future<void> createValidTicket({String? requestId}) {
    return service.createTicket(
      title: 'Falla app',
      description: 'No puedo abrir noticias',
      category: 'app',
      requestId: requestId,
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

      expect(fake.inserted, isNotNull);

      expect(fake.inserted!['user_id'], 'user-a');
      expect(fake.inserted!['title'], 'Error de app');
      expect(fake.inserted!['description'], 'No aparecen los reportes');
      expect(fake.inserted!['category'], 'content');

      // Nueva validación de la práctica 12:
      // cada ticket debe tener request_id UUID.
      final requestId = fake.inserted!['request_id'];

      expect(requestId, isA<String>());

      expect(Uuid.isValidUUID(fromString: requestId as String), isTrue);

      expect(fake.insertCount, 1);
      expect(fake.records, hasLength(1));
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
      expect(fake.records, hasLength(1));
    });

    test('WB-29: permite reintentar tras error', () async {
      fake.insertError = StateError('Temporal');

      await expectLater(createValidTicket(), throwsStateError);

      fake.insertError = null;

      await createValidTicket();

      expect(fake.insertCount, 2);
      expect(fake.records, hasLength(1));
      expect(service.isSubmitting, isFalse);
    });

    test('WB-30: libera bandera tras éxito', () async {
      await createValidTicket();

      expect(service.isSubmitting, isFalse);
      expect(fake.insertCount, 1);
    });
  });

  group('Practicas 13 y 14 - Automatización unitaria', () {
    test('AUT-01: genera un UUID válido para cada operación', () async {
      await createValidTicket();

      final requestId = fake.insertAttempts.single['request_id'];

      expect(requestId, isA<String>());
      expect(Uuid.isValidUUID(fromString: requestId as String), isTrue);
      expect(fake.insertCount, 1);
    });

    test('AUT-02: rechaza un request_id inválido', () async {
      await expectLater(
        createValidTicket(requestId: 'id-invalido'),
        throwsA(isA<TicketValidationException>()),
      );

      expect(fake.insertCount, 0);
      expect(fake.records, isEmpty);
    });

    test('AUT-03: conserva request_id en un reintento', () async {
      fake.insertError = StateError('Error temporal');

      await expectLater(createValidTicket(), throwsStateError);

      final firstRequestId = fake.insertAttempts.first['request_id'];

      fake.insertError = null;

      await createValidTicket();

      final secondRequestId = fake.insertAttempts.last['request_id'];

      expect(firstRequestId, secondRequestId);
      expect(fake.insertCount, 2);
      expect(fake.records, hasLength(1));
    });

    test('AUT-04: genera nuevo ID si cambia el contenido', () async {
      fake.insertError = StateError('Error temporal');

      await expectLater(createValidTicket(), throwsStateError);

      final previousId = fake.insertAttempts.first['request_id'];

      fake.insertError = null;

      await service.createTicket(
        title: 'Otro error',
        description: 'El perfil no se puede actualizar',
        category: 'account',
      );

      final newId = fake.insertAttempts.last['request_id'];

      expect(newId, isNot(previousId));
      expect(fake.insertCount, 2);
      expect(fake.records, hasLength(1));
    });

    test('AUT-05: acepta un UUID proporcionado', () async {
      const operationId = '123e4567-e89b-42d3-a456-426614174000';

      await createValidTicket(requestId: operationId);

      expect(fake.inserted!['request_id'], operationId);

      expect(fake.insertCount, 1);
    });

    test('AUT-06: rechazo de categoría no realiza escritura', () async {
      await expectLater(
        service.createTicket(
          title: 'Problema válido',
          description: 'La aplicación presenta un error',
          category: 'categoria-desconocida',
        ),
        throwsA(isA<TicketValidationException>()),
      );

      expect(fake.insertCount, 0);
      expect(fake.records, isEmpty);
    });
  });
}
