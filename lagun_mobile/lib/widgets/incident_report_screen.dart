import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() =>
      _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _supabase = Supabase.instance.client;

  String _category = 'app';
  bool _submitting = false;
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  final Map<String, String> _categories = {
    'app': 'Error en la aplicación',
    'content': 'Problema con noticias o reseñas',
    'account': 'Problema con mi cuenta',
    'watch': 'Problema con el smartwatch',
    'other': 'Otro',
  };

  final Map<String, String> _statuses = {
    'open': 'Abierto',
    'in_progress': 'En proceso',
    'resolved': 'Resuelto',
    'closed': 'Cerrado',
  };

  final Map<String, String> _priorities = {
    'unassigned': 'Sin asignar',
    'low': 'Baja',
    'medium': 'Media',
    'high': 'Alta',
    'critical': 'Crítica',
  };

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Debes iniciar sesión');
      }

      final response = await _supabase
          .from('support_tickets')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _tickets = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showMessage('Error al cargar tickets: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createTicket() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Debes iniciar sesión', error: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      await _supabase.from('support_tickets').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
      });

      if (!mounted) return;

      _titleController.clear();
      _descriptionController.clear();
      _formKey.currentState!.reset();

      setState(() => _category = 'app');

      _showMessage('Ticket creado correctamente');

      await _loadTickets();
    } catch (e) {
      _showMessage('No se pudo crear el ticket: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Colors.redAccent
            : Colors.green,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.cyanAccent;
      case 'in_progress':
        return Colors.orangeAccent;
      case 'resolved':
        return Colors.greenAccent;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'low':
        return Colors.greenAccent;
      case 'medium':
        return Colors.amberAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'critical':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _inputDecorationLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF201A30),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
      errorMaxLines: 3,
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF130F22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NUEVO REPORTE',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            _inputDecorationLabel('Tipo de incidencia'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              dropdownColor: const Color(0xFF201A30),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Selecciona una categoría'),
              items: _categories.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 16),
            _inputDecorationLabel('Asunto'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 150,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Describe brevemente el problema'),
              validator: (value) {
                if (value == null || value.trim().length < 5) {
                  return 'Escribe un asunto de al menos 5 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _inputDecorationLabel('Descripción'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 3000,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(
                'Explica qué ocurrió y cómo podemos reproducirlo',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 10) {
                  return 'Escribe al menos 10 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'La prioridad será asignada por un administrador.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _createTicket,
                icon: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.confirmation_number_rounded),
                label: Text(
                  _submitting ? 'ENVIANDO...' : 'CREAR TICKET',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicket(Map<String, dynamic> ticket) {
    final status = ticket['status']?.toString() ?? 'open';
    final priority =
        ticket['priority']?.toString() ?? 'unassigned';
    final category = ticket['category']?.toString() ?? 'other';

    final rawDate = ticket['created_at']?.toString();
    final date = rawDate == null ? null : DateTime.tryParse(rawDate);

    final formattedDate = date == null
        ? 'Sin fecha'
        : '${date.toLocal().day.toString().padLeft(2, '0')}/'
          '${date.toLocal().month.toString().padLeft(2, '0')}/'
          '${date.toLocal().year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF130F22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket['title']?.toString() ?? 'Sin título',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _categories[category] ?? category,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Text(
            ticket['description']?.toString() ?? '',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(_statuses[status] ?? status),
                backgroundColor: _statusColor(status).withOpacity(0.15),
                labelStyle: TextStyle(color: _statusColor(status)),
              ),
              Chip(
                label: Text(
                  'Prioridad: ${_priorities[priority] ?? priority}',
                ),
                backgroundColor:
                    _priorityColor(priority).withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _priorityColor(priority),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Creado: $formattedDate',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tickets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Todavía no tienes tickets registrados',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      children: _tickets.map(_buildTicket).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white70),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: RefreshIndicator(
          onRefresh: _loadTickets,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'CENTRO DE REPORTES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reporta incidencias y consulta su seguimiento.',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              _buildForm(),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MIS TICKETS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _loadTickets,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildHistory(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}