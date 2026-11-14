import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/services/ticket_service.dart';

class RecoveryTicketRepository implements TicketRepository {
  final List<Map<String, dynamic>> attempts = [];
  bool firstAttempt = true;

  @override
  String? get currentUserId => '38929a9c-e279-4bdd-900b-d252dade3f12';

  @override
  Future<List<Map<String, dynamic>>> fetchTickets(String userId) async {
    return [];
  }

  @override
  Future<void> insertTicket(Map<String, dynamic> ticket) async {
    attempts.add(Map<String, dynamic>.from(ticket));

    if (firstAttempt) {
      firstAttempt = false;
      throw const SocketException(
        'Respuesta perdida después de guardar el ticket',
      );
    }
  }
}

void main() {
  test('RES-05: conserva request_id tras perder la respuesta', () async {
    final repository = RecoveryTicketRepository();
    final service = TicketService(repository);

    Future<void> submit() {
      return service.createTicket(
        title: 'Reporte de recuperación',
        description:
            'Ticket utilizado para comprobar la recuperación de escritura',
        category: 'app',
      );
    }

    await expectLater(submit(), throwsA(isA<SocketException>()));

    expect(service.isSubmitting, false);
    expect(repository.attempts.length, 1);

    final originalRequestId = repository.attempts.first['request_id'];

    expect(originalRequestId, isA<String>());
    expect(originalRequestId, isNotEmpty);

    await submit();

    expect(repository.attempts.length, 2);
    expect(repository.attempts[1]['request_id'], originalRequestId);

    expect(service.isSubmitting, false);

    await submit();

    expect(repository.attempts.length, 3);
    expect(repository.attempts[2]['request_id'], isNot(originalRequestId));
  });
}
