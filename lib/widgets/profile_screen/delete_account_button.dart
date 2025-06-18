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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: TextButton(
          onPressed: onDelete,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
