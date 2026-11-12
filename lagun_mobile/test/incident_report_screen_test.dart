import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/services/ticket_service.dart';
import 'package:lagun_mobile/widgets/incident_report_screen.dart';

class FakeTicketRepository implements TicketRepository {
  @override
  String? currentUserId = 'usuario-prueba';

  List<Map<String, dynamic>> tickets = [];

  bool failOnLoad = false;
  bool failOnInsert = false;

  int loadCount = 0;
  int insertCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchTickets(String userId) async {
    loadCount++;

    if (failOnLoad) {
      throw Exception('Error de consulta simulado');
    }

    return tickets.where((ticket) => ticket['user_id'] == userId).toList();
  }

  @override
  Future<void> insertTicket(Map<String, dynamic> ticket) async {
    insertCount++;

    if (failOnInsert) {
      throw Exception('Error de inserción simulado');
    }

    tickets.add({
      'id': 'ticket-$insertCount',
      ...ticket,
      'status': 'open',
      'priority': 'unassigned',
      'created_at': '2026-11-11T18:00:00Z',
    });
  }
}

void main() {
  late FakeTicketRepository repository;

  setUp(() {
    repository = FakeTicketRepository();
  });

  Future<void> openReports(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IncidentReportScreen(repository: repository)),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> findOnScreen(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);

    await tester.ensureVisible(fields.at(0));

    await tester.enterText(fields.at(0), 'Error de aplicación');

    await tester.ensureVisible(fields.at(1));

    await tester.enterText(
      fields.at(1),
      'La aplicación no muestra las noticias.',
    );

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  Future<void> submitForm(WidgetTester tester) async {
    final button = find.text('CREAR TICKET');

    await findOnScreen(tester, button);

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('White Box - Interfaz REPORTES', () {
    testWidgets('WB-31: muestra formulario de reportes', (tester) async {
      await openReports(tester);

      expect(find.text('CENTRO DE REPORTES'), findsOneWidget);

      expect(find.text('NUEVO REPORTE'), findsOneWidget);

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('WB-32: muestra historial vacío', (tester) async {
      await openReports(tester);

      await findOnScreen(
        tester,
        find.text('Todavía no tienes tickets registrados'),
      );

      expect(
        find.text('Todavía no tienes tickets registrados'),
        findsOneWidget,
      );
    });

    testWidgets('WB-33: carga tickets existentes', (tester) async {
      repository.tickets = [
        {
          'id': 'ticket-1',
          'user_id': 'usuario-prueba',
          'title': 'Problema de acceso',
          'description': 'No puedo abrir la aplicación.',
          'category': 'account',
          'status': 'open',
          'priority': 'low',
          'created_at': '2026-11-11T18:00:00Z',
        },
      ];

      await openReports(tester);

      await findOnScreen(tester, find.text('Problema de acceso'));

      expect(find.text('Problema de acceso'), findsOneWidget);

      expect(repository.loadCount, 1);
    });

    testWidgets('WB-34: controla errores de consulta', (tester) async {
      repository.failOnLoad = true;

      await openReports(tester);

      expect(repository.loadCount, 1);

      expect(find.textContaining('Error al cargar tickets'), findsOneWidget);
    });

    testWidgets('WB-35: rechaza formulario vacío', (tester) async {
      await openReports(tester);

      await submitForm(tester);

      expect(repository.insertCount, 0);

      expect(
        find.text('Escribe un asunto de al menos 5 caracteres'),
        findsOneWidget,
      );

      expect(find.text('Escribe al menos 10 caracteres'), findsOneWidget);
    });

    testWidgets('WB-36: crea un ticket válido', (tester) async {
      await openReports(tester);

      await fillForm(tester);
      await submitForm(tester);

      expect(repository.insertCount, 1);

      expect(repository.tickets.first['title'], 'Error de aplicación');

      expect(repository.tickets.first['user_id'], 'usuario-prueba');
    });

    testWidgets('WB-37: actualiza historial después de crear', (tester) async {
      await openReports(tester);

      final initialLoads = repository.loadCount;

      await fillForm(tester);
      await submitForm(tester);

      expect(repository.loadCount, initialLoads + 1);

      await findOnScreen(tester, find.text('Error de aplicación'));

      expect(find.text('Error de aplicación'), findsOneWidget);
    });

    testWidgets('WB-38: controla errores de inserción', (tester) async {
      repository.failOnInsert = true;

      await openReports(tester);

      await fillForm(tester);
      await submitForm(tester);

      expect(repository.insertCount, 1);

      expect(repository.tickets, isEmpty);

      expect(find.textContaining('No se pudo crear el ticket'), findsOneWidget);
    });

    testWidgets('WB-39: rechaza usuario no autenticado', (tester) async {
      repository.currentUserId = null;

      await openReports(tester);

      await fillForm(tester);
      await submitForm(tester);

      expect(repository.insertCount, 0);

      expect(find.textContaining('Debes iniciar sesión'), findsWidgets);
    });

    testWidgets('WB-40: muestra estado y prioridad', (tester) async {
      repository.tickets = [
        {
          'id': 'ticket-40',
          'user_id': 'usuario-prueba',
          'title': 'Problema crítico',
          'description': 'El sistema presenta un error.',
          'category': 'app',
          'status': 'in_progress',
          'priority': 'critical',
          'created_at': '2026-11-11T18:00:00Z',
        },
      ];

      await openReports(tester);

      await findOnScreen(tester, find.text('Problema crítico'));

      expect(find.text('En proceso'), findsOneWidget);

      expect(find.text('Prioridad: Crítica'), findsOneWidget);
    });
  });
}
