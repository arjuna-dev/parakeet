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
    return ListTile(
      leading: const Icon(Icons.notifications),
      title: const Text('Daily Practice Reminder'),
      subtitle: Text(reminderTime != null ? 'Reminder set for ${reminderTime!.format(context)}' : 'No reminder set'),
      trailing: reminderTime != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            )
          : null,
      onTap: onTap,
    );
  }
}
