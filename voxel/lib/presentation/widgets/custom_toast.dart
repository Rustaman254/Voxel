import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, info, warning }

class CustomToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final VoidCallback? onClose;

  const CustomToast({
    super.key,
    required this.message,
    this.type = ToastType.info,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        backgroundColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline;
        break;
      case ToastType.error:
        backgroundColor = const Color(0xFFFFEBEE);
        iconColor = const Color(0xFFC62828);
        icon = Icons.error_outline;
        break;
      case ToastType.warning:
        backgroundColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFEF6C00);
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        backgroundColor = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF1565C0);
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: backgroundColor, width: 2), // Subtle colored border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
            ),
          ],
        ],
      ),
    );
  }
}
