import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A top-level module card (large, for the module dashboard).
class ModuleCard extends StatefulWidget {
  const ModuleCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.description,
    this.meta,
    this.metaIcon,
    this.comingSoon = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? description;
  final String? meta;
  final IconData? metaIcon;
  final bool comingSoon;

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.comingSoon ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: GestureDetector(
          onTapDown: (_) {
            if (!widget.comingSoon) _controller.forward();
          },
          onTapUp: (_) {
            if (!widget.comingSoon) {
              _controller.reverse();
              widget.onTap();
            }
          },
          onTapCancel: () => _controller.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _isHovered && !widget.comingSoon ? -4 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered && !widget.comingSoon
                    ? widget.color.withValues(alpha: 0.45)
                    : const Color(0xFFE5E8E2),
                width: _isHovered && !widget.comingSoon ? 1.5 : 1.2,
              ),
              boxShadow: [
                if (_isHovered && !widget.comingSoon) ...[
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] else ...[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon Box + Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color,
                            Color.alphaBlend(Colors.black.withValues(alpha: 0.18), widget.color),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    if (!widget.comingSoon)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isHovered
                              ? widget.color
                              : const Color(0xFFF4F6F3),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: _isHovered
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Bottom Meta or Coming Soon Badge
                if (widget.comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else if (widget.meta != null)
                  Row(
                    children: [
                      if (widget.metaIcon != null) ...[
                        Icon(
                          widget.metaIcon,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        widget.meta!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: widget.color.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sub-module icon card (smaller, for within a module).
class SubModuleCard extends StatefulWidget {
  const SubModuleCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<SubModuleCard> createState() => _SubModuleCardState();
}

class _SubModuleCardState extends State<SubModuleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color;
    final secondaryColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.18),
      widget.color,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap();
          },
          onTapCancel: () => _controller.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHovered
                    ? primaryColor.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: [
                if (_isHovered) ...[
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ] else ...[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.32),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable header for sub-module screens with back button and profile.
class ModuleScreenHeader extends StatelessWidget {
  const ModuleScreenHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.onBack,
    this.employeeName,
    this.photoUrl,
    this.onProfile,
    this.actions,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onBack;
  final String? employeeName;
  final String? photoUrl;
  final VoidCallback? onProfile;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.textPrimary,
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    Color.alphaBlend(Colors.black.withValues(alpha: 0.18), color),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (actions != null) ...actions!,
            if (employeeName != null) ...[
              if (actions != null && actions!.isNotEmpty) const SizedBox(width: 8),
              GestureDetector(
                onTap: onProfile,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employeeName!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAvatar(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final cleanPhoto = photoUrl?.trim() ?? '';
    final initial = employeeName != null && employeeName!.isNotEmpty
        ? employeeName![0].toUpperCase()
        : '?';

    if (cleanPhoto.isNotEmpty) {
      if (cleanPhoto.startsWith('data:')) {
        try {
          final commaIdx = cleanPhoto.indexOf(',');
          final bytes = base64Decode(
            commaIdx != -1 ? cleanPhoto.substring(commaIdx + 1) : cleanPhoto,
          );
          return CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primary,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (cleanPhoto.startsWith('http://') || cleanPhoto.startsWith('https://')) {
        return CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primary,
          backgroundImage: NetworkImage(cleanPhoto),
        );
      }
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
