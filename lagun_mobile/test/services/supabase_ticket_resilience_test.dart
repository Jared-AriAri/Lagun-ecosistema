
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lagun_mobile/services/supabase_ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const userId = '38929a9c-e279-4bdd-900b-d252dade3f12';

  SupabaseTicketRepository createRepository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient(handler),
    );

    return SupabaseTicketRepository(client);
  }

  http.Response successfulResponse(http.Request request) {
    return http.Response(
      jsonEncode([
        {
          'id': 'bced382a-b324-4d55-a6da-74640aaee930',
          'user_id': userId,
          'title': 'Ticket de prueba',
          'status': 'open',
        },
      ]),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  test('RES-01: propaga la pérdida de conexión', () async {
    final repository = createRepository((request) async {
      throw const SocketException('Sin conexión a internet');
    });

    await expectLater(
      repository.fetchTickets(userId),
      throwsA(isA<SocketException>()),
    );
  });

  test(
    'RES-02: recupera la lectura tras una interrupción temporal',
    () async {
      var attempts = 0;

      final repository = createRepository((request) async {
        attempts++;

        if (attempts == 1) {
          throw const SocketException('Conexión interrumpida');
        }

        return successfulResponse(request);
      });

      final tickets = await repository.fetchTickets(userId);

      expect(attempts, greaterThanOrEqualTo(2));
      expect(tickets.length, 1);
      expect(tickets.first['title'], 'Ticket de prueba');
    },
  );

  test('RES-03: identifica un error HTTP 503', () async {
    final repository = createRepository((request) async {
      return http.Response(
        jsonEncode({
          'code': 'PGRST503',
          'message': 'Servicio temporalmente no disponible',
        }),
        503,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });

    await expectLater(
      repository.fetchTickets(userId),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('RES-04: propaga un tiempo de espera agotado', () async {
    var attempts = 0;

    final repository = createRepository((request) async {
      attempts++;

      throw const SocketException(
        'Connection timed out',
        osError: OSError('Operation timed out', 60),
      );
    });

    await expectLater(
      repository.fetchTickets(userId),
      throwsA(isA<SocketException>()),
    );

    expect(attempts, greaterThanOrEqualTo(1));
  });
}
