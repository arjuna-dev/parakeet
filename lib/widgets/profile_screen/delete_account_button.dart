import 'package:flutter/material.dart';

class DeleteAccountButton extends StatelessWidget {
  final VoidCallback onDelete;

  const DeleteAccountButton({
    Key? key,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Padding(
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
          onTap: onDelete,
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
    );
  }
}
