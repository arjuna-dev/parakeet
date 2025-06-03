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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onDelete,
          child: Text(
            'Delete Account',
            style: TextStyle(
              color: colorScheme.error,
              fontStyle: FontStyle.italic,
              fontSize: isSmallScreen ? 15 : 16,
            ),
          ),
        ),
      ),
    );
  }
}
