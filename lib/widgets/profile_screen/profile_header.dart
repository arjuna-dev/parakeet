import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;

  const ProfileHeader({
    Key? key,
    required this.name,
    required this.email,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    String getInitial() {
      if (name.isNotEmpty) {
        return name[0].toUpperCase();
      }
      if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }
      return '?';
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: isSmallScreen ? 40 : 50,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                getInitial(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 32 : 40,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              name.isNotEmpty ? name : email,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (name.isNotEmpty)
              Text(
                email,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
