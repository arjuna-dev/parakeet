import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/screens/profile_screen.dart';

class AppBarWithDrawer extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const AppBarWithDrawer({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showDrawerMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(buildContext).size.width * 0.8,
                height: MediaQuery.of(buildContext).size.height,
                decoration: BoxDecoration(
                  color: Theme.of(buildContext).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      decoration: BoxDecoration(
                        color: Theme.of(buildContext).colorScheme.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu,
                            color: Theme.of(buildContext).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Menu',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (Navigator.canPop(buildContext)) {
                                Navigator.pop(buildContext);
                              }
                            },
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(buildContext).colorScheme.surface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Menu items
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildMenuItem(
                              buildContext,
                              icon: Icons.list_alt,
                              title: 'Word Management',
                              subtitle: 'Track your learning progress',
                              onTap: () {
                                if (Navigator.canPop(buildContext)) {
                                  Navigator.pop(buildContext);
                                }
                                Navigator.pushNamed(buildContext, '/word_management');
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildMenuItem(
                              buildContext,
                              icon: Icons.person,
                              title: 'Profile',
                              subtitle: 'Settings and account info',
                              onTap: () {
                                if (Navigator.canPop(buildContext)) {
                                  Navigator.pop(buildContext);
                                }
                                Navigator.pushNamed(buildContext, '/profile');
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildMenuItem(
                              buildContext,
                              icon: Icons.language,
                              title: 'Language Settings',
                              subtitle: 'Change your learning languages',
                              onTap: () {
                                if (Navigator.canPop(buildContext)) {
                                  Navigator.pop(buildContext);
                                }
                                ProfileScreen.showLanguageSettingsDialog(buildContext);
                              },
                            ),
                            const Spacer(),
                            _buildMenuItem(
                              buildContext,
                              icon: Icons.logout,
                              title: 'Sign Out',
                              subtitle: 'Log out of your account',
                              iconColor: Colors.red,
                              onTap: () async {
                                if (Navigator.canPop(buildContext)) {
                                  Navigator.pop(buildContext);
                                }
                                await _showSignOutConfirmation(buildContext);
                              },
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: effectiveIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: effectiveIconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSignOutConfirmation(BuildContext context) async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      final authService = AuthService();
      await authService.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _showDrawerMenu(context),
      ),
    );
  }
}
