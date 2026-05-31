import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isSaving  = false;

  final _usernameController = TextEditingController();
  final _bioController      = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final apiService = context.read<ApiService>();
    final profile    = await apiService.fetchProfile();
    if (!mounted) return;
    setState(() {
      _user      = profile;
      _isLoading = false;
      if (profile != null) {
        _usernameController.text = profile['username'] ?? '';
        _bioController.text      = profile['bio'] ?? '';
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked == null) return;
    setState(() => _isSaving = true);
    final apiService   = context.read<ApiService>();
    final updatedUser  = await apiService.updateProfile(avatarPath: picked.path);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (updatedUser != null) _user = updatedUser;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar updated!')),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final apiService   = context.read<ApiService>();
    final updatedUser  = await apiService.updateProfile(
      username: _usernameController.text.trim(),
      bio:      _bioController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (updatedUser != null) _user = updatedUser;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );
  }

  void _logout() async {
    final apiService = context.read<ApiService>();
    await apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Avatar ────────────────────────────────────────
                  GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kAccent, width: 2),
                              gradient: _user?['avatar_url'] == null
                                  ? kAccentGradient as Gradient
                                  : null,
                              image: _user?['avatar_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage('$baseUrl${_user!['avatar_url']}'),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _user?['avatar_url'] == null
                                ? Center(
                                    child: Text(
                                      (_user?['username'] ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: kTextPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 2, right: 2,
                          child: Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(
                              gradient: kAccentGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 15, color: kTextPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email label
                  Text(
                    _user?['email'] ?? '',
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // ── Fields ───────────────────────────────────────
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline, color: kTextMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.edit_note_rounded, color: kTextMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Save Button ──────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Logout ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: kRed, size: 18),
                      label: const Text('Sign Out', style: TextStyle(color: kRed)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kRed, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
