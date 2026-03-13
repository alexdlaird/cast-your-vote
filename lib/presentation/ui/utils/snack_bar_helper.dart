import 'package:flutter/material.dart';

enum SnackType {
  info,
  error;

  Color? backgroundColor(BuildContext context) {
    return switch (this) {
      SnackType.info => null,
      SnackType.error => Theme.of(context).colorScheme.error,
    };
  }
}

class SnackBarHelper {
  static void show(
    BuildContext context,
    String message, {
    int seconds = 4,
    SnackType type = SnackType.info,
    bool clearSnackBars = true,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    if (clearSnackBars) {
      messenger.clearSnackBars();
    }

    final controller = messenger.showSnackBar(
      SnackBar(
        content: SelectableText(message),
        backgroundColor: type.backgroundColor(context),
        duration: Duration(seconds: seconds),
        action: action,
      ),
    );

    // SnackBar won't automatically close with an action, so close manually.
    if (action != null) {
      Future.delayed(Duration(seconds: seconds), () {
        try {
          controller.close();
        } catch (_) {
          // SnackBar may have already been dismissed.
        }
      });
    }
  }
}
