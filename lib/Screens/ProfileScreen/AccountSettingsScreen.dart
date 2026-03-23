import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountSettingsScreen extends StatelessWidget {
  AccountSettingsScreen({super.key});

  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authController.clearSession();
      _authController.changeTab(AuthTabs.login);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'This action is permanent and will remove your BeatNow account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _beatNowService.deleteAccount();
      await _authController.clearSession();
      _authController.changeTab(AuthTabs.login);
    } on ApiException catch (error) {
      Get.snackbar('Error', error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _authController.changeTab(AuthTabs.profile),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121212), Color(0xFF0D0D0D)],
            stops: [0.5, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildListTile('Log Out', Icons.exit_to_app, () => _confirmLogout(context)),
                  _buildListTile(
                    'Delete Account',
                    Icons.delete,
                    () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '© BeatNow Development',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String title, IconData icon, VoidCallback onTap) {
    final danger = title == 'Delete Account';

    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: danger ? Colors.red : Colors.white),
      ),
      leading: Icon(icon, color: danger ? Colors.red : Colors.white),
      onTap: onTap,
    );
  }
}
