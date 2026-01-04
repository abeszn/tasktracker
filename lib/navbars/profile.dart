import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tasktracker/pages/login.dart';// Replace with your login screen path
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _avatarUrl;
  late String _username;
  bool _saving = false;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
    //Fetch username from profiles table
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();

    final meta = user.userMetadata ?? {};

    setState(() {
      _username = profile!['username'] as String;
      _avatarUrl = (meta['avatar_url'] as String?);
      _loadingProfile = false;
    });
  } catch (e) {
  if (!mounted) return;
  setState(() => _loadingProfile = false);
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text('Failed to load profile: $e'),
  backgroundColor: Colors.red,
  ),
  );
  }
}

  Future<void> _pickAndUploadAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (picked == null) return;
      final file = File(picked.path);
      final path = 'avatars/${user.id}.png';
      // Create bucket named 'avatars' in Supabase storage and set it public or add signed URL logic
      await Supabase.instance.client.storage.from('avatars').upload(path, file, fileOptions: const FileOptions(upsert: true));
      final publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
      setState(() => _avatarUrl = publicUrl);
      await _saveAvatar(publicUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _saveAvatar(String url) async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating avatar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Padding(
        padding: const EdgeInsets.only(left: 8.0, top: 30.0),
        child: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _loadingProfile
          ? const CircularProgressIndicator(color: Colors.deepOrange)
          : Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface),
                    icon: _saving
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    :const Icon(Icons.camera_alt),
                    onPressed: _saving ? null : _pickAndUploadAvatar,
                    tooltip: 'Change avatar',
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),

            Text(
              _username,
              style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold,
              height: 1.5,
              fontSize: 30),
            ),
            const SizedBox(height: 32),

            //logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                onPressed: () => _logout(context),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
