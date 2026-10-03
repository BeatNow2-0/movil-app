import 'dart:io';

import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/Screens/ProfileScreen/profileother_screen.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:BeatNow/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  final UserSingleton _user = UserSingleton();

  bool _isLoading = true;
  bool _isPhotoUpdating = false;
  List<Posts> _posts = <Posts>[];
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted && _profile == null) setState(() => _isLoading = true);
    try {
      final profile = await _beatNowService.getUserProfile(_user.id);
      final username = profile['username']?.toString() ?? _user.username;
      _user
        ..username = username
        ..name = profile['full_name']?.toString() ?? ''
        ..profileImageUrl = MediaDefaults.profileUrl(profile);
      List<Posts> posts = <Posts>[];
      if (username.isNotEmpty) {
        try {
          posts = await _beatNowService.getUserPosts(username);
        } catch (error) {
          debugPrint('Error loading own beats: $error');
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error is ApiException
                ? error.userMessage
                : 'Could not load profile')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openBeatViewer(int index) async {
    if (index < 0 || index >= _posts.length) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileBeatViewer(
          posts: _posts,
          initialIndex: index,
          producerName: _user.username,
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;
      setState(() => _isPhotoUpdating = true);
      await _beatNowService.changeProfilePhoto(File(pickedFile.path).path);
      await MediaDefaults.profileImageProvider(_user.profileImageUrl).evict();
      await _beatNowService.getCurrentUser();
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException
              ? error.userMessage
              : 'Could not update profile photo'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPhotoUpdating = false);
    }
  }

  Future<void> _deletePhoto() async {
    try {
      setState(() => _isPhotoUpdating = true);
      await _beatNowService.deleteProfilePhoto();
      await MediaDefaults.profileImageProvider(_user.profileImageUrl).evict();
      await _beatNowService.getCurrentUser();
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException
              ? error.userMessage
              : 'Could not remove profile photo'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPhotoUpdating = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BeatNowTokens.surface0,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_outlined, color: Colors.white),
                title: const Text('Take photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                title: const Text('Choose from gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_user.profileImageUrl != MediaDefaults.profileImage)
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.white),
                  title: const Text('Remove profile photo',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePhoto();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: BeatNowTokens.space1),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(BeatNowTokens.radiusLarge)),
                      color: BeatNowTokens.surface1,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                onPressed: () {
                                  _authController.changeTab(AuthTabs.home);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  '@${_user.username}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.tune_rounded,
                                    color: Colors.white),
                                onPressed: () => _authController
                                    .changeTab(AuthTabs.accountSettings),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _isPhotoUpdating ? null : _showPhotoOptions,
                            child: Center(
                              child: Stack(
                                children: [
                                  ProfileAvatar(
                                    imageUrl: _user.profileImageUrl,
                                    initial: _user.username,
                                    size: 116,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: BeatNowTokens.surface2,
                                      child: _isPhotoUpdating
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_outlined,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: BeatNowTokens.space4),
                          Text(
                            _user.name.isEmpty ? _user.username : _user.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '@${_user.username}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: BeatNowTokens.space2),
                            child: Row(
                              children: [
                                if (_posts.isNotEmpty) ...[
                                  _buildStat('Beats', '${_posts.length}'),
                                  const SizedBox(width: BeatNowTokens.space2),
                                ],
                                _buildStat('Following',
                                    '${_profile?['following'] ?? 0}'),
                                const SizedBox(width: BeatNowTokens.space2),
                                _buildStat('Followers',
                                    '${_profile?['followers'] ?? 0}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _authController.changeTab(AuthTabs.saved),
                          icon: const Icon(Icons.bookmark_border_rounded),
                          label: const Text('Saved'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _authController.changeTab(AuthTabs.lyrics),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Lyrics'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.settings_outlined,
                        color: Colors.white70),
                    title: const Text('Account settings'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _authController.changeTab(AuthTabs.accountSettings),
                  ),
                  if (_posts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Beats',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _posts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 9 / 16,
                      ),
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return ClipRRect(
                          borderRadius:
                              BorderRadius.circular(BeatNowTokens.radiusMedium),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openBeatViewer(index),
                              child: CachedMediaImage(
                                url: post.coverImageUrl,
                                fallbackAsset: MediaDefaults.coverImage,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
