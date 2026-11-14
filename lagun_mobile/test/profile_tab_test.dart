import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lagun_mobile/widgets/profile_tab.dart';

void main() {
  registerProfileAvatarWhiteBoxTests();
  Future<void> showBase(
    WidgetTester tester, {
    bool isLoading = false,
    String? successMessage,
    String? errorMessage,
    String? role,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileTab(
            nameController: TextEditingController(text: 'Persona de prueba'),
            bioController: TextEditingController(text: 'Biografía de prueba'),
            isLoading: isLoading,
            email: 'prueba@lagun.test',
            role: role,
            successMessage: successMessage,
            errorMessage: errorMessage,
            onSave: () {},
            onLogout: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('White Box - Perfil básico', () {
    testWidgets('PRT-01: muestra formulario de perfil', (tester) async {
      await showBase(tester, role: 'reader');
      expect(find.text('prueba@lagun.test'), findsOneWidget);
      expect(find.text('READER'), findsOneWidget);
      expect(find.text('NOMBRE COMPLETO'), findsOneWidget);
      expect(find.text('BIOGRAFÍA'), findsOneWidget);
      expect(find.text('ACTUALIZAR DATOS'), findsOneWidget);
      expect(find.text('CERRAR SESIÓN'), findsOneWidget);
    });

    testWidgets('PRT-02: muestra el estado de guardado', (tester) async {
      await showBase(tester, isLoading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('PRT-03: muestra éxito y error por separado', (tester) async {
      await showBase(tester, successMessage: 'GUARDADO');
      expect(find.text('GUARDADO'), findsOneWidget);
      await showBase(tester, errorMessage: 'NO SE PUDO GUARDAR');
      expect(find.text('NO SE PUDO GUARDAR'), findsOneWidget);
      expect(find.text('GUARDADO'), findsNothing);
    });
  });
}

void registerProfileAvatarWhiteBoxTests() {
  Future<void> showProfile(
    WidgetTester tester, {
    Future<XFile?> Function()? picker,
    String? Function()? userId,
    Future<void> Function(String path, File file)? upload,
    Future<void> Function(Map<String, dynamic> values)? save,
    void Function(String url)? changed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileTab(
            nameController: TextEditingController(),
            bioController: TextEditingController(),
            isLoading: false,
            onSave: () {},
            onLogout: () {},
            onAvatarChanged: changed,
            avatarPickerOverride: picker,
            avatarUserIdOverride: userId,
            avatarFileUploadOverride: upload,
            avatarPublicUrlOverride: (_) => 'https://example.test/avatar.png',
            avatarProfileUpsertOverride: save,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<File> makeAvatar(WidgetTester tester) async {
    final file = await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('lagun_avatar_');
      final image = File('${directory.path}/foto.png');
      await image.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgZGT8DwABDQED5NTSmwAAAABJRU5ErkJggg==',
        ),
      );
      return image;
    });
    final avatar = file!;
    addTearDown(() async {
      if (await avatar.parent.exists()) {
        await avatar.parent.delete(recursive: true);
      }
    });
    return avatar;
  }

  group('White Box - Subida de avatar', () {
    testWidgets('WB-143: cancelar la selección no inicia una subida', (
      tester,
    ) async {
      var uploads = 0;
      await showProfile(
        tester,
        picker: () async => null,
        upload: (path, file) async {
          uploads++;
        },
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(uploads, 0);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('WB-144: selección fallida es controlada', (tester) async {
      await showProfile(
        tester,
        picker: () async =>
            throw const FileSystemException('Galería inaccesible'),
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-145: no intenta subir si el usuario no está autenticado', (
      tester,
    ) async {
      var uploads = 0;
      await showProfile(
        tester,
        picker: () async => XFile('/ruta-inexistente/avatar.png'),
        userId: () => null,
        upload: (path, file) async {
          uploads++;
        },
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(uploads, 0);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('WB-146: subida y persistencia del avatar correctas', (
      tester,
    ) async {
      final image = await makeAvatar(tester);
      String? uploadedPath;
      String? changedUrl;
      Map<String, dynamic>? savedValues;

      await showProfile(
        tester,
        picker: () async => XFile(image.path),
        userId: () => 'usuario-prueba',
        upload: (path, file) async {
          uploadedPath = path;
          expect(file.path, image.path);
        },
        save: (values) async {
          savedValues = values;
        },
        changed: (url) => changedUrl = url,
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(uploadedPath, startsWith('usuario-prueba_'));
      expect(uploadedPath, endsWith('.png'));
      expect(savedValues?['id'], 'usuario-prueba');
      expect(savedValues?['avatar_url'], 'https://example.test/avatar.png');
      expect(
        DateTime.tryParse(savedValues?['updated_at'] as String),
        isNotNull,
      );
      expect(changedUrl, 'https://example.test/avatar.png');
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('WB-147: fallo de subida evita persistir avatar', (
      tester,
    ) async {
      final image = await makeAvatar(tester);
      var saved = 0;
      var changed = 0;
      await showProfile(
        tester,
        picker: () async => XFile(image.path),
        userId: () => 'usuario-prueba',
        upload: (path, file) async =>
            throw const SocketException('Error de red'),
        save: (_) async {
          saved++;
        },
        changed: (_) => changed++,
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(saved, 0);
      expect(changed, 0);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('WB-149: fallo al guardar en perfil no publica un avatar', (
      tester,
    ) async {
      final image = await makeAvatar(tester);
      var uploaded = 0;
      var changed = 0;
      await showProfile(
        tester,
        picker: () async => XFile(image.path),
        userId: () => 'usuario-prueba',
        upload: (path, file) async {
          uploaded++;
        },
        save: (values) async =>
            throw const SocketException('Error de almacenamiento'),
        changed: (_) => changed++,
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(uploaded, 1);
      expect(changed, 0);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('WB-148: bloquea segunda subida mientras la primera termina', (
      tester,
    ) async {
      final image = await makeAvatar(tester);
      final pending = Completer<void>();
      var uploaded = 0;
      await showProfile(
        tester,
        picker: () async => XFile(image.path),
        userId: () => 'usuario-prueba',
        upload: (path, file) async {
          uploaded++;
          await pending.future;
        },
        save: (_) async {},
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(uploaded, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(uploaded, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
