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
    final response = await client
        .from('support_tickets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> insertTicket(Map<String, dynamic> ticket) async {
    await client.from('support_tickets').insert(ticket);
  }
}
