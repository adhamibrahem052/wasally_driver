import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_providers.dart';

final _editProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return null;
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.from('profiles').select().eq('id', user.id).single();
  return AppUser.fromMap(res);
});

class DriverEditProfileScreen extends ConsumerStatefulWidget {
  const DriverEditProfileScreen({super.key});
  @override
  ConsumerState<DriverEditProfileScreen> createState() => _DriverEditProfileScreenState();
}

class _DriverEditProfileScreenState extends ConsumerState<DriverEditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _saving = false;
  bool _showPasswordFields = false;
  File? _avatarFile;
  String? _existingAvatarUrl;

  String tr(String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    final user = ref.read(driverAuthProvider).supabaseUser;
    if (user == null) return;
    final newPassword = _newPasswordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
      if (newPassword.length < 8) {
        if (mounted) showErrorDialog(context, tr('passwordMinLength'));
        return;
      }
      if (!RegExp(r'[0-9]').hasMatch(newPassword)) {
        if (mounted) showErrorDialog(context, tr('passwordNumberRequired'));
        return;
      }
      if (newPassword != confirmPassword) {
        if (mounted) showErrorDialog(context, tr('passwordMismatch'));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      String? avatarUrl = _existingAvatarUrl;
      if (_avatarFile != null) {
        final ext = _avatarFile!.path.split('.').last;
        final path = 'avatars/${user.id}.$ext';
        final supabase = ref.read(supabaseClientProvider);
        await supabase.storage.from('profiles').upload(path, _avatarFile!, fileOptions: FileOptions(upsert: true));
        avatarUrl = supabase.storage.from('profiles').getPublicUrl(path);
      }
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', user.id);

      if (newPassword.isNotEmpty) {
        await supabase.auth.updateUser(UserAttributes(password: newPassword));
      }

      ref.invalidate(driverProfileProvider);
      ref.invalidate(_editProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newPassword.isNotEmpty ? tr('passwordChangedToast') : tr('changesSavedToast'), style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_editProfileProvider);
    final t = tr;

    return Scaffold(
      appBar: AppBar(title: Text(t('editProfile'), style: GoogleFonts.cairo())),
      body: profileAsync.when(
        loading: () => const WasallyLoading(),
        error: (_, __) => WasallyError(message: t('profileLoadError')),
        data: (profile) {
          if (profile == null) return WasallyError(message: t('profileNotAvailable'));
          if (_nameCtrl.text.isEmpty) {
            _nameCtrl.text = profile.fullName;
            _phoneCtrl.text = profile.phoneNumber ?? '';
            _addressCtrl.text = profile.address ?? '';
            _existingAvatarUrl = profile.avatarUrl;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFFF9800),
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!)
                            : (_existingAvatarUrl != null ? NetworkImage(_existingAvatarUrl!) : null),
                        child: (_avatarFile == null && _existingAvatarUrl == null)
                            ? const Icon(Icons.person, size: 48, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9800),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: t('nameField'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneCtrl,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: t('phoneField'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressCtrl,
                textAlign: TextAlign.right,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t('addressField'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showPasswordFields = !_showPasswordFields),
                  icon: Icon(_showPasswordFields ? Icons.expand_less : Icons.lock_outline, size: 18),
                  label: Text(t('changePasswordBtn'), style: GoogleFonts.cairo()),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                ),
              ),
              if (_showPasswordFields) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordCtrl,
                  textAlign: TextAlign.right,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t('newPassword'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordCtrl,
                  textAlign: TextAlign.right,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t('confirmNewPassword'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(t('save'), style: GoogleFonts.cairo(fontSize: 16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
