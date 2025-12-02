import 'package:flutter/material.dart';

class ReminderTile extends StatelessWidget {
  final TimeOfDay? reminderTime;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const ReminderTile({
    Key? key,
    required this.reminderTime,
    required this.onTap,
    this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 2,
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.notifications,
          color: colorScheme.primary,
        ),
        title: const Text('Daily Practice Reminder'),
        subtitle: Text(reminderTime != null ? 'Reminder set for ${reminderTime!.format(context)}' : 'No reminder set'),
        trailing: reminderTime != null
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: onClear,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
