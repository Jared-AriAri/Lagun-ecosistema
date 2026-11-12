import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileTab extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController bioController;
  final bool isLoading;
  final String? avatarUrl;
  final String? email;
  final String? role;
  final String? successMessage;
  final String? errorMessage;
  final VoidCallback onSave;
  final VoidCallback onLogout;
  final Function(String newAvatarUrl)? onAvatarChanged;

  const ProfileTab({
    super.key,
    required this.nameController,
    required this.bioController,
    required this.isLoading,
    this.avatarUrl,
    this.email,
    this.role,
    this.successMessage,
    this.errorMessage,
    required this.onSave,
    required this.onLogout,
    this.onAvatarChanged,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isUploadingImage = false;
  File? _selectedImageFile;
  Uint8List? _webImageBytes;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final fileExt = pickedFile.name.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
        });
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
      } else {
        final file = File(pickedFile.path);
        setState(() {
          _selectedImageFile = file;
        });
        await Supabase.instance.client.storage
            .from('avatars')
            .upload(filePath, file, fileOptions: const FileOptions(upsert: true));
      }

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (widget.onAvatarChanged != null) {
        widget.onAvatarChanged!(imageUrl);
      }
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.greenAccent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF130F22),
                    backgroundImage: _webImageBytes != null
                        ? MemoryImage(_webImageBytes!)
                        : (_selectedImageFile != null
                            ? FileImage(_selectedImageFile!) as ImageProvider
                            : (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                                ? NetworkImage(widget.avatarUrl!)
                                : null)),
                    child: (_webImageBytes == null &&
                            _selectedImageFile == null &&
                            (widget.avatarUrl == null || widget.avatarUrl!.isEmpty))
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.greenAccent,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _isUploadingImage ? null : _pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0A0712), width: 2),
                      ),
                      child: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.black,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.email ?? 'CARGANDO CORREO...',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          if (widget.role != null && widget.role!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.role!.toUpperCase(),
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (widget.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                border: Border.all(
                  color: Colors.redAccent,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (widget.successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                border: Border.all(
                  color: Colors.greenAccent,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.successMessage!,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          TextField(
            controller: widget.nameController,
            style: const TextStyle(
              color: Colors.white,
            ),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'NOMBRE COMPLETO',
              labelStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              filled: true,
              fillColor: const Color(0xFF130F22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.bioController,
            maxLines: 4,
            maxLength: 250,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'BIOGRAFÍA',
              labelStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              hintText: 'Cuéntanos un poco sobre ti',
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              filled: true,
              fillColor: const Color(0xFF130F22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    Colors.greenAccent.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 5,
                shadowColor:
                    Colors.greenAccent.withOpacity(0.5),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'ACTUALIZAR DATOS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(
                Icons.power_settings_new,
                color: Colors.redAccent,
                size: 18,
              ),
              label: const Text(
                'CERRAR SESIÓN',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.redAccent,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}