import 'package:flutter/foundation.dart';
import 'package:lagun_mobile/services/ticket_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTicketRepository implements TicketRepository {
  final SupabaseClient client;

  SupabaseTicketRepository(this.client);

  @override
  String? get currentUserId {
    return client.auth.currentUser?.id;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTickets(String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await client
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final tickets = List<Map<String, dynamic>>.from(response);

      stopwatch.stop();

      debugPrint(
        'PER-03 | fetchTickets | '
        '${stopwatch.elapsedMilliseconds} ms | '
        '${tickets.length} registros | OK',
      );

      return tickets;
    } catch (e) {
      stopwatch.stop();

      debugPrint(
        'PER-03 | fetchTickets | '
        '${stopwatch.elapsedMilliseconds} ms | ERROR: $e',
      );

      rethrow;
    }
  }

  @override
  Future<void> insertTicket(Map<String, dynamic> ticket) async {
    final userId = ticket['user_id'] as String?;
    final requestId = ticket['request_id'] as String?;

    if (userId == null || requestId == null) {
      throw ArgumentError('La inserción requiere user_id y request_id');
    }

    try {
      await client.from('support_tickets').insert(ticket);
    } on PostgrestException catch (e) {
      final isRequestIdConflict =
          e.code == '23505' &&
          e.message.contains('support_tickets_user_request_unique');

      if (!isRequestIdConflict) {
        rethrow;
      }

      final existing = await client
          .from('support_tickets')
          .select(
            'id, user_id, request_id, title, '
            'description, category',
          )
          .eq('user_id', userId)
          .eq('request_id', requestId)
          .maybeSingle();

      if (existing == null) {
        rethrow;
      }

      final matchesOriginalRequest =
          existing['title'] == ticket['title'] &&
          existing['description'] == ticket['description'] &&
          existing['category'] == ticket['category'];

      if (!matchesOriginalRequest) {
        throw StateError('El request_id ya pertenece a otra operación');
      }

      debugPrint(
        'DEF-02 | Reintento detectado | '
        'Ticket existente: ${existing['id']}',
      );
    }
  }
}
