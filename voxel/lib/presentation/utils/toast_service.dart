import 'package:flutter/material.dart';
import '../widgets/custom_toast.dart';

class ToastService {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: CustomToast(message: message, type: type),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.all(20),
        padding: EdgeInsets.zero, // Important to remove default padding
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, type: ToastType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, type: ToastType.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message, type: ToastType.info);
  }
  
  static void showWarning(BuildContext context, String message) {
    show(context, message, type: ToastType.warning);
  }
}
