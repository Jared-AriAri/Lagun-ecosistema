import 'dart:convert';

import 'package:lagun_mobile/validators/ticket_validator.dart';
import 'package:uuid/uuid.dart';

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

  static const Uuid _uuid = Uuid();

  bool _submitting = false;
  String? _pendingRequestId;
  String? _pendingPayload;

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
    String? requestId,
  }) async {
    if (_submitting) {
      throw const TicketSubmissionInProgress();
    }

    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();

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

    final payloadIdentity = jsonEncode([
      userId,
      normalizedTitle,
      normalizedDescription,
      category,
    ]);

    final String operationId;

    if (requestId != null) {
      if (!Uuid.isValidUUID(fromString: requestId)) {
        throw const TicketValidationException(
          'Identificador de operación no válido',
        );
      }

      operationId = requestId;
    } else if (_pendingPayload == payloadIdentity &&
        _pendingRequestId != null) {
      operationId = _pendingRequestId!;
    } else {
      operationId = _uuid.v4();
    }

    _pendingRequestId = operationId;
    _pendingPayload = payloadIdentity;
    _submitting = true;

    try {
      await repository.insertTicket({
        'user_id': userId,
        'request_id': operationId,
        'title': normalizedTitle,
        'description': normalizedDescription,
        'category': category,
      });

      _pendingRequestId = null;
      _pendingPayload = null;
    } finally {
      _submitting = false;
    }
  }
}
