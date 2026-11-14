
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/widgets/home_screen.dart';
import 'package:lagun_mobile/widgets/news_list.dart';
import 'package:lagun_mobile/widgets/profile_tab.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<void> showHome(
    WidgetTester tester, {
    Future<List<Map<String, dynamic>>> Function()? newsFetcher,
    Future<List<Map<String, dynamic>>> Function()? reviewsFetcher,
    Future<HomeProfileIdentity?> Function()? identityFetcher,
    Future<Map<String, dynamic>?> Function(String userId)? profileFetcher,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          enableExternalServices: false,
          newsFetcher: newsFetcher,
          reviewsFetcher: reviewsFetcher,
          identityFetcher: identityFetcher,
          profileFetcher: profileFetcher,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('PERFIL'));
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> emptyItems() async {
    return <Map<String, dynamic>>[];
  }

  Future<HomeProfileIdentity?> validIdentity() async {
    return const HomeProfileIdentity(
      id: 'usuario-prueba',
      email: 'prueba@lagun.test',
    );
  }

  group('White Box - Supabase y carga de datos', () {
    testWidgets(
      'WB-119: carga noticias y reseñas correctamente',
      (tester) async {
        await mockNetworkImagesFor(() async {
          var newsCalls = 0;
          var reviewCalls = 0;

          await showHome(
            tester,
            newsFetcher: () async {
              newsCalls++;

              return [
                {
                  'id': 'noticia-119',
                  'slug': 'tecnologia',
                  'title': 'Tecnología actual',
                  'excerpt': 'Avances recientes',
                  'cover_image_url': null,
                },
              ];
            },
            reviewsFetcher: () async {
              reviewCalls++;

              return [
                {
                  'id': 'resena-119',
                  'slug': 'videojuego',
                  'title': 'Análisis del videojuego',
                  'rating': 9,
                  'cover_image_url': null,
                },
              ];
            },
          );

          final newsList = tester.widget<NewsListSection>(
            find.byType(NewsListSection),
          );

          expect(newsList.items.length, 1);
          expect(newsList.items.first.title, 'Tecnología actual');
          expect(newsList.items.first.subtitle, 'Avances recientes');
          expect(newsList.items.first.tag, 'NOTICIA');
          expect(newsCalls, 1);
          expect(reviewCalls, 1);

          await tester.tap(find.text('RESEÑAS'));
          await tester.pumpAndSettle();

          final reviewsList = tester.widget<NewsListSection>(
            find.byType(NewsListSection),
          );

          expect(reviewsList.items.length, 1);
          expect(reviewsList.items.first.title, 'Análisis del videojuego');
          expect(reviewsList.items.first.tag, 'RESEÑA');
          expect(reviewsList.items.first.score, '9/10');
        });
      },
    );

    testWidgets(
      'WB-120: carga vacía no genera publicaciones falsas',
      (tester) async {
        await showHome(
          tester,
          newsFetcher: emptyItems,
          reviewsFetcher: emptyItems,
        );

        final newsList = tester.widget<NewsListSection>(
          find.byType(NewsListSection),
        );

        expect(newsList.items, isEmpty);
        expect(
          find.text('No se encontraron publicaciones'),
          findsOneWidget,
        );

        await tester.tap(find.text('RESEÑAS'));
        await tester.pumpAndSettle();

        final reviewsList = tester.widget<NewsListSection>(
          find.byType(NewsListSection),
        );

        expect(reviewsList.items, isEmpty);
      },
    );

    testWidgets(
      'WB-121: utiliza valores predeterminados para campos nulos',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await showHome(
            tester,
            newsFetcher: () async {
              return [
                {
                  'id': 'noticia-121',
                  'slug': null,
                  'title': null,
                  'excerpt': null,
                  'cover_image_url': null,
                },
              ];
            },
            reviewsFetcher: () async {
              return [
                {
                  'id': 'resena-121',
                  'slug': null,
                  'title': 'Reseña sin puntuación',
                  'rating': null,
                  'cover_image_url': null,
                },
              ];
            },
          );

          final newsList = tester.widget<NewsListSection>(
            find.byType(NewsListSection),
          );

          expect(newsList.items.length, 1);
          expect(newsList.items.first.id, 'noticia-121');
          expect(newsList.items.first.slug, '');
          expect(newsList.items.first.title, '');
          expect(newsList.items.first.subtitle, '');

          await tester.tap(find.text('RESEÑAS'));
          await tester.pumpAndSettle();

          final reviewsList = tester.widget<NewsListSection>(
            find.byType(NewsListSection),
          );

          expect(reviewsList.items.length, 1);
          expect(reviewsList.items.first.slug, '');
          expect(reviewsList.items.first.score, 'N/A');
        });
      },
    );

    testWidgets(
      'WB-122: error de red activa el modo offline',
      (tester) async {
        var reviewCalls = 0;

        await showHome(
          tester,
          newsFetcher: () async {
            throw const SocketException('Sin conexión');
          },
          reviewsFetcher: () async {
            reviewCalls++;
            return [];
          },
        );

        expect(
          find.text('MODO OFFLINE · Sin conexión con Supabase'),
          findsOneWidget,
        );

        expect(reviewCalls, 0);

        final newsList = tester.widget<NewsListSection>(
          find.byType(NewsListSection),
        );

        expect(newsList.items, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WB-123: carga correctamente el perfil existente',
      (tester) async {
        String? requestedUserId;
        var profileCalls = 0;

        await showHome(
          tester,
          identityFetcher: validIdentity,
          profileFetcher: (userId) async {
            requestedUserId = userId;
            profileCalls++;

            return {
              'full_name': 'Usuario de Prueba',
              'bio': 'Biografía de prueba',
              'avatar_url': null,
              'role': 'reader',
            };
          },
        );

        await openProfile(tester);

        final profile = tester.widget<ProfileTab>(
          find.byType(ProfileTab),
        );

        expect(requestedUserId, 'usuario-prueba');
        expect(profileCalls, greaterThanOrEqualTo(1));
        expect(profile.email, 'prueba@lagun.test');
        expect(profile.role, 'reader');
        expect(profile.nameController.text, 'Usuario de Prueba');
        expect(profile.bioController.text, 'Biografía de prueba');
        expect(profile.errorMessage, isNull);
      },
    );

    testWidgets(
      'WB-124: usuario sin sesión no consulta el perfil',
      (tester) async {
        var profileCalls = 0;

        await showHome(
          tester,
          identityFetcher: () async => null,
          profileFetcher: (userId) async {
            profileCalls++;
            return {
              'full_name': 'No debería cargarse',
            };
          },
        );

        await openProfile(tester);

        final profile = tester.widget<ProfileTab>(
          find.byType(ProfileTab),
        );

        expect(profileCalls, 0);
        expect(profile.email, isNull);
        expect(profile.nameController.text, isEmpty);
        expect(profile.bioController.text, isEmpty);
        expect(profile.errorMessage, isNull);
      },
    );

    testWidgets(
      'WB-125: perfil inexistente muestra mensaje de error',
      (tester) async {
        await showHome(
          tester,
          identityFetcher: validIdentity,
          profileFetcher: (userId) async => null,
        );

        await openProfile(tester);

        final profile = tester.widget<ProfileTab>(
          find.byType(ProfileTab),
        );

        expect(profile.email, 'prueba@lagun.test');
        expect(
          profile.errorMessage,
          'No se encontró tu perfil. Comprueba que se haya creado al registrarte.',
        );

        expect(
          find.text(
            'No se encontró tu perfil. Comprueba que se haya creado al registrarte.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'WB-126: error de permisos de Supabase se maneja correctamente',
      (tester) async {
        await showHome(
          tester,
          identityFetcher: validIdentity,
          profileFetcher: (userId) async {
            throw const PostgrestException(
              message: 'permission denied for table profiles',
              code: '42501',
            );
          },
        );

        await openProfile(tester);

        final profile = tester.widget<ProfileTab>(
          find.byType(ProfileTab),
        );

        expect(profile.email, 'prueba@lagun.test');
        expect(
          profile.errorMessage,
          'Error al cargar perfil: permission denied for table profiles',
        );

        expect(
          find.text(
            'Error al cargar perfil: permission denied for table profiles',
          ),
          findsOneWidget,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
