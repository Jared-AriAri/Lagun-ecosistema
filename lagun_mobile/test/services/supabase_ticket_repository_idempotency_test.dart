import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lagun_mobile/services/supabase_ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseTicketRepository repository;
  late List<http.Request> requests;

  SupabaseTicketRepository createRepository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );

    repository = SupabaseTicketRepository(client);
    return repository;
  }

  setUp(() {
    requests = [];
  });

  group('White Box - SupabaseTicketRepository', () {
    test('WB-168: crea correctamente el repositorio Supabase', () async {
      createRepository(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );

      expect(repository, isA<SupabaseTicketRepository>());

      expect(repository.client, same(client));
      expect(requests, isEmpty);
    });

    test('WB-169: sin autenticación devuelve usuario nulo', () async {
      createRepository(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );

      expect(client.auth.currentUser, isNull);
      expect(repository.currentUserId, isNull);
      expect(requests, isEmpty);
    });

    test('WB-170: consulta tickets filtrados por usuario', () async {
      const userId = 'usuario-wb170';

      createRepository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/support_tickets');

        expect(request.url.queryParameters['user_id'], 'eq.$userId');

        expect(
          request.url.queryParameters['order'],
          'created_at.desc.nullslast',
        );

        return http.Response(
          jsonEncode([
            {
              'id': 'ticket-001',
              'user_id': userId,
              'title': 'Problema de noticias',
              'status': 'open',
            },
            {
              'id': 'ticket-002',
              'user_id': userId,
              'title': 'Problema de perfil',
              'status': 'open',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      });

      final result = await repository.fetchTickets(userId);

      expect(result, hasLength(2));

      expect(result.every((ticket) => ticket['user_id'] == userId), isTrue);

      expect(result.first['id'], 'ticket-001');
      expect(result.last['id'], 'ticket-002');

      expect(requests, hasLength(1));
    });

    test('WB-171: consulta sin resultados devuelve lista vacía', () async {
      const userId = 'usuario-sin-tickets';

      createRepository(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        ),
      );

      final result = await repository.fetchTickets(userId);

      expect(result, isEmpty);
      expect(requests, hasLength(1));

      expect(requests.single.method, 'GET');

      expect(requests.single.url.path, '/rest/v1/support_tickets');

      expect(requests.single.url.queryParameters['user_id'], 'eq.$userId');
    });

    test('WB-172: inserta un ticket con los datos correctos', () async {
      createRepository(
        (request) async => http.Response(
          '',
          201,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      const requestId = '123e4567-e89b-42d3-a456-426614174000';

      final ticket = <String, dynamic>{
        'user_id': 'usuario-wb172',
        'request_id': requestId,
        'title': 'Problema con una noticia',
        'description': 'El contenido de la noticia no se muestra correctamente',
        'category': 'content',
        'status': 'open',
      };

      await repository.insertTicket(ticket);

      expect(requests, hasLength(1));

      final request = requests.single;

      expect(request.method, 'POST');

      expect(request.url.path, '/rest/v1/support_tickets');

      final sentData = jsonDecode(request.body) as Map<String, dynamic>;

      expect(sentData['user_id'], 'usuario-wb172');
      expect(sentData['request_id'], requestId);

      expect(sentData['title'], 'Problema con una noticia');

      expect(sentData['description'], ticket['description']);

      expect(sentData['category'], 'content');
      expect(sentData['status'], 'open');

      // Verifica que el repositorio conserva
      // todos los campos sin alterar el contenido.
      expect(sentData, ticket);
    });

    test('WB-173: propaga errores de acceso denegado de Supabase', () async {
      const userId = 'usuario-sin-permiso';

      createRepository(
        (request) async => http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied for table support_tickets',
            'details': null,
            'hint': null,
          }),
          403,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        repository.fetchTickets(userId),
        throwsA(
          isA<PostgrestException>()
              .having((error) => error.code, 'código PostgreSQL', '42501')
              .having(
                (error) => error.message,
                'mensaje de error',
                contains('permission denied'),
              ),
        ),
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');

      expect(requests.single.url.queryParameters['user_id'], 'eq.$userId');
    });
  });
}
