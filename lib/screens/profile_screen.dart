import 'package:flutter/material.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String _name = '';
  String _email = '';
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('userDoc email: ${userData['email']}');
        setState(() {
          _name = userData['name'] ?? '';
          _email = userData['email'] ?? '';
          _premium = userData['premium'] ?? false;
        });
      }
    }
  }

  void _deleteAccount() async {
    print('email: $_email');
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _authService.deleteAccount();
        // Navigate to login or home screen after account deletion
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Widget _buildProfileHeader() {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    String getInitial() {
      if (_name.isNotEmpty) {
        return _name[0].toUpperCase();
      }
      if (_email.isNotEmpty) {
        return _email[0].toUpperCase();
      }
      return '?';
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: isSmallScreen ? 40 : 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                getInitial(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 32 : 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              _name.isNotEmpty ? _name : _email,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_name.isNotEmpty)
              Text(
                _email,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 8 : 12,
        ),
        leading: Container(
          width: isSmallScreen ? 40 : 48,
          height: isSmallScreen ? 40 : 48,
          decoration: BoxDecoration(
            color: (iconColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
            size: isSmallScreen ? 20 : 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 15 : 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.primary,
          size: isSmallScreen ? 24 : 28,
        ),
        onTap: onTap,
      ),
    );
  }

  void _handleStoreNavigation() {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.phone_android, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Mobile App Required'),
              ],
            ),
            content: const Text(
              'Please use the Parakeet mobile app to view and purchase premium features.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StoreView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildMenuItem(
              icon: _premium ? Icons.star : Icons.star_border,
              iconColor: _premium ? Colors.amber : null,
              title: _premium ? 'Premium Member' : 'Free Account',
              subtitle: _premium ? 'Enjoy unlimited access' : 'Upgrade to premium for more features',
              onTap: _handleStoreNavigation,
            ),
            _buildMenuItem(
              icon: Icons.shopping_bag,
              title: 'Store',
              subtitle: 'View available packages and offers',
              onTap: _handleStoreNavigation,
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs and contact information',
              onTap: () {
                _launchURL(Uri(scheme: "https", host: "gregarious-giant-4a5.notion.site", path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26"));
              },
            ),
            _buildMenuItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              onTap: () {
                _launchURL(Uri.parse("https://parakeet.world/privacypolicy"));
              },
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.error.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: _deleteAccount,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_forever,
                          color: colorScheme.error,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 15 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
          ],
        ),
      ),
    );
  }
}

void _launchURL(Uri url) async {
  await canLaunchUrl(url) ? await launchUrl(url) : throw 'Could not launch $url';
}
