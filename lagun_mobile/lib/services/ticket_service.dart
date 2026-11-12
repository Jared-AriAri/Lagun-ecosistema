import 'package:lagun_mobile/validators/ticket_validator.dart';

abstract class TicketRepository {
  String? get currentUserId;

  Future<List<Map<String, dynamic>>> fetchTickets(String userId);

  Future<void> insertTicket(Map<String, dynamic> ticket);
}

class TicketNotAuthenticated implements Exception {
  const TicketNotAuthenticated();

  @override
  String toString() => 'Debes iniciar sesión';
}

class TicketValidationException implements Exception {
  final String message;

  const TicketValidationException(this.message);

  @override
  String toString() => message;
}

class TicketSubmissionInProgress implements Exception {
  const TicketSubmissionInProgress();

  @override
  String toString() => 'Ya se está enviando un ticket';
}

class TicketService {
  final TicketRepository repository;

  bool _submitting = false;

  TicketService(this.repository);

  bool get isSubmitting => _submitting;

  Future<List<Map<String, dynamic>>> loadTickets() async {
    final userId = repository.currentUserId;

    if (userId == null) {
      throw const TicketNotAuthenticated();
    }

    return repository.fetchTickets(userId);
  }

  Future<void> createTicket({
    required String title,
    required String description,
    required String category,
  }) async {
    if (_submitting) {
      throw const TicketSubmissionInProgress();
    }

    final titleError = TicketValidator.validateTitle(title);

    if (titleError != null) {
      throw TicketValidationException(titleError);
    }

    final descriptionError = TicketValidator.validateDescription(description);

    if (descriptionError != null) {
      throw TicketValidationException(descriptionError);
    }

    const allowedCategories = {'app', 'content', 'account', 'watch', 'other'};

    if (!allowedCategories.contains(category)) {
      throw const TicketValidationException('Categoría no válida');
    }

    final userId = repository.currentUserId;

    if (userId == null) {
      throw const TicketNotAuthenticated();
    }

    _submitting = true;

    try {
      await repository.insertTicket({
        'user_id': userId,
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
      });
    } finally {
      _submitting = false;
    }
  }
}
