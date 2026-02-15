import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VoxelAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const VoxelAvatar({
    super.key,
    this.avatarUrl,
    this.displayName,
    this.radius = 20,
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFFB452FF),
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final isSvg = hasUrl && (avatarUrl!.contains('.svg') || avatarUrl!.contains('/svg'));

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: hasUrl
            ? isSvg
                ? SvgPicture.network(
                    avatarUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholderBuilder: (context) => _buildPlaceholder(),
                  )
                : Image.network(
                    avatarUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final initials = displayName != null && displayName!.isNotEmpty
        ? displayName!.substring(0, 1).toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
