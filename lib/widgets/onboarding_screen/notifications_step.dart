import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:parakeet/services/notification_service.dart';
import 'dart:io';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  print("Checking notification permission...");

  var status = await Permission.notification.status;
  print("Current permission status: $status");

  if (status.isDenied || status.isPermanentlyDenied) {
    print("Requesting notification permission...");
    var result = await Permission.notification.request();
    print("Permission request result: $result");
  }
}

Future<bool?> requestExactAlarmPermission() async {
  print("Checking exact alarm permission...");

  try {
    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      print("Requesting exact alarm permission...");
      bool? granted = await androidPlugin.requestExactAlarmsPermission();

      return granted;
    } else {
      print("Android plugin not found.");
      return null;
    }
  } on PlatformException catch (e) {
    print("Error requesting exact alarm permission: $e");
    return null;
  }
}

class NotificationsPermissionsStep extends StatelessWidget {
  final bool? notificationsEnabled;
  final Function(bool) onNotificationsEnabledChanged;

  final NotificationService _notificationService = NotificationService();

  NotificationsPermissionsStep({
    Key? key,
    required this.notificationsEnabled,
    required this.onNotificationsEnabledChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.notifications, size: 64),
        const SizedBox(height: 24),
        Text(
          'Would you like to receive notifications?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Get reminders to practice and stay on track',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Yes, please button
            ElevatedButton(
              onPressed: () async {
                onNotificationsEnabledChanged(true);
                // Request both notifications and exact alarm permissions.
                await requestNotificationPermission();
                if (Platform.isAndroid) {
                  bool? alarmPermissions = await requestExactAlarmPermission();
                  if (alarmPermissions == null || !alarmPermissions) {
                    onNotificationsEnabledChanged(false);
                  } else {
                    await _notificationService.scheduleDailyReminder(NotificationService.defaultReminderTime);
                  }
                } else {
                  await _notificationService.scheduleDailyReminder(NotificationService.defaultReminderTime);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: notificationsEnabled == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: notificationsEnabled == true ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
              ),
              child: const Text("Yes, please"),
            ),
            const SizedBox(width: 20),
            // No, thanks button
            ElevatedButton(
              onPressed: () {
                onNotificationsEnabledChanged(false);
                _notificationService.cancelDailyReminder();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: notificationsEnabled == false ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: notificationsEnabled == false ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
              ),
              child: const Text("No, thanks"),
            ),
          ],
        ),
      ],
    );
  }
}
