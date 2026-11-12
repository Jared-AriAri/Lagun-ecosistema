class TicketValidator {
  static String? validateTitle(String? value) {
    if (value == null || value.trim().length < 5) {
      return 'Escribe un asunto de al menos 5 caracteres';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    if (value == null || value.trim().length < 10) {
      return 'Escribe al menos 10 caracteres';
    }
    return null;
  }
}
