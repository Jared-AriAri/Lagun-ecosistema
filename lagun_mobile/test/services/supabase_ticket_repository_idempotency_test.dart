import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lagun_mobile/services/supabase_ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const userId = '38929a9c-e279-4bdd-900b-d252dade3f12';
  const requestId = 'ec2f3b89-f551-4fb1-8c5e-52ce2e2ec19a';
  const ticketId = 'd0b6b666-2c46-403c-ba7c-5a59e1eba380';

  Map<String, dynamic> ticket() => {
    'user_id': userId,
    'request_id': requestId,
    'title': 'Prueba de idempotencia',
    'description': 'Descripcion valida para comprobar reintentos',
    'category': 'app',
  };

  SupabaseTicketRepository repositoryWith(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient(handler),
    );

    return SupabaseTicketRepository(client);
  }

  http.Response duplicateConflict(http.Request request) {
    return http.Response(
      jsonEncode({
        'code': '23505',
        'message':
            'duplicate key value violates unique constraint '
            '"support_tickets_user_request_unique"',
        'details': 'Key (user_id, request_id) already exists.',
      }),
      409,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  test('DEF-02-01: crea el ticket correctamente', () async {
    var postCount = 0;

    final repository = repositoryWith((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/support_tickets');

      postCount++;

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['request_id'], requestId);
      expect(body['user_id'], userId);

      return http.Response('', 201, request: request);
    });

    await repository.insertTicket(ticket());

    expect(postCount, 1);
  });

  test('DEF-02-02: recupera el ticket ante un reintento duplicado', () async {
    var postCount = 0;
    var getCount = 0;

    final repository = repositoryWith((request) async {
      if (request.method == 'POST') {
        postCount++;
        return duplicateConflict(request);
      }

      if (request.method == 'GET') {
        getCount++;

        expect(request.url.path, '/rest/v1/support_tickets');

        expect(request.url.queryParameters['request_id'], 'eq.$requestId');

        return http.Response(
          jsonEncode({'id': ticketId, ...ticket()}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      return http.Response('Metodo inesperado', 405, request: request);
    });

    await repository.insertTicket(ticket());

    expect(postCount, 1);
    expect(getCount, 1);
  });

  test('DEF-02-03: rechaza request_id asociado a otros datos', () async {
    var getCount = 0;

    final repository = repositoryWith((request) async {
      if (request.method == 'POST') {
        return duplicateConflict(request);
      }

      if (request.method == 'GET') {
        getCount++;

        return http.Response(
          jsonEncode({
            'id': ticketId,
            ...ticket(),
            'title': 'Otro ticket diferente',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      return http.Response('Metodo inesperado', 405, request: request);
    });

    await expectLater(
      repository.insertTicket(ticket()),
      throwsA(isA<StateError>()),
    );

    expect(getCount, 1);
  });
}
