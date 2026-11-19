import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lagun_mobile/services/supabase_ticket_repository.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('White Box - SupabaseTicketRepository', () {
    late SupabaseClient client;
    late SupabaseTicketRepository repository;
    late List<http.Request> requests;

    void createRepository(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      requests = [];

      client = SupabaseClient(
        'https://lagun-pruebas.supabase.co',
        'clave-publica-de-pruebas',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
      );

      repository = SupabaseTicketRepository(client);

      addTearDown(() async {
        await client.dispose();
      });
    }

    test('WB-168: crea correctamente el repositorio Supabase', () {
      createRepository(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      expect(repository, isA<SupabaseTicketRepository>());
      expect(identical(repository.client, client), isTrue);
      expect(requests, isEmpty);
    });

    test('WB-169: sin autenticación devuelve usuario nulo', () {
      createRepository(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      expect(client.auth.currentUser, isNull);
      expect(repository.currentUserId, isNull);
      expect(requests, isEmpty);
    });

    test('WB-170: consulta tickets filtrados por usuario', () async {
      const userId = 'usuario-wb170';

      final tickets = [
        {
          'id': 'ticket-002',
          'user_id': userId,
          'title': 'Segundo reporte',
          'description': 'Descripción del segundo reporte',
          'category': 'content',
          'status': 'open',
          'created_at': '2026-11-13T12:00:00Z',
        },
        {
          'id': 'ticket-001',
          'user_id': userId,
          'title': 'Primer reporte',
          'description': 'Descripción del primer reporte',
          'category': 'content',
          'status': 'open',
          'created_at': '2026-11-12T12:00:00Z',
        },
      ];

      createRepository(
        (request) async => http.Response(
          jsonEncode(tickets),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final result = await repository.fetchTickets(userId);

      expect(result, hasLength(2));
      expect(result.first['id'], 'ticket-002');
      expect(result.last['id'], 'ticket-001');
      expect(result.every((ticket) => ticket['user_id'] == userId), isTrue);

      expect(requests, hasLength(1));

      final request = requests.single;

      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/support_tickets');
      expect(request.url.queryParameters['user_id'], 'eq.$userId');
      expect(request.url.queryParameters['order'], 'created_at.desc.nullslast');
      expect(request.url.queryParameters['select'], '*');
    });

    test('WB-171: consulta sin resultados devuelve lista vacía', () async {
      createRepository(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final result = await repository.fetchTickets('usuario-sin-tickets');

      expect(result, isEmpty);
      expect(result, isA<List<Map<String, dynamic>>>());

      expect(requests, hasLength(1));
      expect(
        requests.single.url.queryParameters['user_id'],
        'eq.usuario-sin-tickets',
      );
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

      final ticket = <String, dynamic>{
        'user_id': 'usuario-wb172',
        'request_id': '123e4567-e89b-42d3-a456-426614174000',
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
      expect(sentData['title'], 'Problema con una noticia');
      expect(sentData['description'], ticket['description']);
      expect(sentData['category'], 'content');
      expect(sentData['status'], 'open');
      expect(sentData, ticket);
    });

    test('WB-173: propaga errores de acceso denegado de Supabase', () async {
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
        repository.fetchTickets('usuario-sin-permisos'),
        throwsA(
          isA<PostgrestException>()
              .having((error) => error.code, 'code', '42501')
              .having(
                (error) => error.message,
                'message',
                contains('permission denied'),
              ),
        ),
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
    });
  });
}
