// lib/utils/app_notifications.dart
import 'package:flutter/material.dart';

enum NotificationType { success, error, warning }

class AppNotifications {
  static void showSnackBar(BuildContext context, String message, {NotificationType type = NotificationType.error}) {
    Color backgroundColor;
    IconData iconData;

    switch (type) {
      case NotificationType.success:
        backgroundColor = Colors.green.shade700;
        iconData = Icons.check_circle_outline;
        break;
      case NotificationType.error:
        backgroundColor = Colors.red.shade800;
        iconData = Icons.highlight_off;
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange.shade800;
        iconData = Icons.warning_amber_rounded;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Vazir', color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}