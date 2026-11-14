import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/widgets/home_screen.dart';
import 'package:lagun_mobile/widgets/profile_tab.dart';
import 'package:lagun_mobile/widgets/telemetry_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<HomeProfileIdentity?> validIdentity() async {
    return const HomeProfileIdentity(
      id: 'usuario-wb',
      email: 'pruebas@lagun.test',
    );
  }

  Future<void> showHome(
    WidgetTester tester, {
    Future<HomeProfileIdentity?> Function()? identityFetcher,
    Future<Map<String, dynamic>?> Function(
      String userId,
      Map<String, dynamic> values,
    )?
    profileUpdater,
    Future<void> Function(Map<String, dynamic> values)? metricsUpsertOverride,
    Uint8List? packet,
    Future<List<Map<String, dynamic>>> Function()? newsFetcher,
    Future<List<Map<String, dynamic>>> Function()? reviewsFetcher,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          enableExternalServices: false,
          identityFetcher: identityFetcher,
          profileUpdater: profileUpdater,
          metricsUpsertOverride: metricsUpsertOverride,
          initialBinaryPacket: packet,
          newsFetcher: newsFetcher,
          reviewsFetcher: reviewsFetcher,
        ),
      ),
    );
    await tester.pump();
  }

  Future<ProfileTab> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('PERFIL'));
    await tester.pumpAndSettle();
    return tester.widget<ProfileTab>(find.byType(ProfileTab));
  }

  Future<void> saveProfile(WidgetTester tester) async {
    final tab = tester.widget<ProfileTab>(find.byType(ProfileTab));
    tab.onSave();
    await tester.pumpAndSettle();
  }

  group('White Box - Escrituras de perfil y sincronizacion', () {
    testWidgets('WB-127: guarda nombre y biografia recortados', (tester) async {
      String? capturedId;
      Map<String, dynamic>? capturedValues;
      var calls = 0;

      await showHome(
        tester,
        identityFetcher: validIdentity,
        profileUpdater: (id, values) async {
          calls++;
          capturedId = id;
          capturedValues = Map<String, dynamic>.from(values);
          return {'id': id};
        },
      );

      final profile = await openProfile(tester);
      profile.nameController.text = '  Ana López  ';
      profile.bioController.text = '  Biografía nueva  ';
      await saveProfile(tester);

      final updated = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(calls, 1);
      expect(capturedId, 'usuario-wb');
      expect(capturedValues, {
        'full_name': 'Ana López',
        'bio': 'Biografía nueva',
      });
      expect(updated.successMessage, 'CONFIGURACIÓN GUARDADA EXITOSAMENTE');
      expect(updated.errorMessage, isNull);
      expect(updated.isLoading, isFalse);
    });

    testWidgets('WB-128: rechaza guardado sin usuario autenticado', (
      tester,
    ) async {
      var calls = 0;
      await showHome(
        tester,
        identityFetcher: () async => null,
        profileUpdater: (id, values) async {
          calls++;
          return {'id': id};
        },
      );
      await openProfile(tester);
      await saveProfile(tester);
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(calls, 0);
      expect(profile.errorMessage, contains('Usuario no autenticado'));
      expect(profile.successMessage, isNull);
      expect(profile.isLoading, isFalse);
    });

    testWidgets('WB-129: informa cuando no hay perfil autorizado', (
      tester,
    ) async {
      await showHome(
        tester,
        identityFetcher: validIdentity,
        profileUpdater: (id, values) async => null,
      );
      await openProfile(tester);
      await saveProfile(tester);
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(
        profile.errorMessage,
        contains('No se encontró un perfil autorizado'),
      );
      expect(profile.successMessage, isNull);
      expect(profile.isLoading, isFalse);
    });

    testWidgets('WB-130: controla error de permisos 42501 al guardar', (
      tester,
    ) async {
      await showHome(
        tester,
        identityFetcher: validIdentity,
        profileUpdater: (id, values) async {
          throw const PostgrestException(
            message: 'permission denied for table profiles',
            code: '42501',
          );
        },
      );
      await openProfile(tester);
      await saveProfile(tester);
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(
        profile.errorMessage,
        'Error 42501: permission denied for table profiles',
      );
      expect(profile.successMessage, isNull);
      expect(profile.isLoading, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-131: bloquea guardados simultaneos', (tester) async {
      final completer = Completer<Map<String, dynamic>?>();
      var calls = 0;
      await showHome(
        tester,
        identityFetcher: validIdentity,
        profileUpdater: (id, values) {
          calls++;
          return completer.future;
        },
      );
      final profile = await openProfile(tester);
      profile.onSave();
      profile.onSave();
      await tester.pump();
      final pending = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(calls, 1);
      expect(pending.isLoading, isTrue);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      completer.complete({'id': 'usuario-wb'});
      await tester.pumpAndSettle();
      final finished = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(calls, 1);
      expect(finished.isLoading, isFalse);
      expect(finished.successMessage, 'CONFIGURACIÓN GUARDADA EXITOSAMENTE');
    });

    testWidgets(
      'WB-132: sincroniza el paquete decodificado con el usuario correcto',
      (tester) async {
        Map<String, dynamic>? saved;
        var calls = 0;
        await showHome(
          tester,
          identityFetcher: validIdentity,
          packet: Uint8List.fromList([1, 2, 40, 65]),
          metricsUpsertOverride: (values) async {
            calls++;
            saved = Map<String, dynamic>.from(values);
          },
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(saved, isNotNull);
        expect(saved!['user_id'], 'usuario-wb');
        expect(saved!['reading_time_sec'], 258);
        expect(saved!['articles_read'], 40);
        expect(saved!['scroll_activity'], 65);
        expect(saved!['stress_level'], 65);
        expect(saved!['sleep_quality'], 40);
        expect(DateTime.tryParse(saved!['updated_at'] as String), isNotNull);
        final bar = tester.widget<TelemetryBar>(find.byType(TelemetryBar));
        expect(bar.isConnected, isTrue);
      },
    );

    testWidgets('WB-133: error de red al sincronizar muestra modo offline', (
      tester,
    ) async {
      await showHome(
        tester,
        identityFetcher: validIdentity,
        packet: Uint8List.fromList([0, 1, 80, 20]),
        metricsUpsertOverride: (values) async {
          throw const SocketException('Sin conexión al sincronizar');
        },
      );
      await tester.pumpAndSettle();
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-134: sincronizacion exitosa recupera estado online', (
      tester,
    ) async {
      final pendingWrite = Completer<void>();
      var calls = 0;
      await showHome(
        tester,
        identityFetcher: validIdentity,
        packet: Uint8List.fromList([0, 4, 80, 30]),
        newsFetcher: () async {
          throw const SocketException('Sin red para noticias');
        },
        reviewsFetcher: () async => [],
        metricsUpsertOverride: (values) {
          calls++;
          return pendingWrite.future;
        },
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsOneWidget,
      );
      pendingWrite.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
