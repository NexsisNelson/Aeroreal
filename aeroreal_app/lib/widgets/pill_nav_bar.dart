import 'package:flutter/material.dart';

import '../utils/app_icons.dart';

class PillNavItem {
  final FaIconData icon;
  final FaIconData selectedIcon;
  final String label;

  const PillNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class PillNavBar extends StatelessWidget {
  final List<PillNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const PillNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalPadding = 16.0;
            final extraSelectedWidth =
                (constraints.maxWidth - horizontalPadding - items.length * 44)
                    .clamp(0.0, 72.0);
            final itemWidth =
                (constraints.maxWidth -
                    horizontalPadding -
                    12 -
                    extraSelectedWidth) /
                items.length;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1625),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < items.length; index++)
                    _PillNavButton(
                      item: items[index],
                      selected: index == selectedIndex,
                      width:
                          itemWidth +
                          (index == selectedIndex ? extraSelectedWidth : 0),
                      onTap: () => onSelect(index),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PillNavButton extends StatelessWidget {
  final PillNavItem item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  const _PillNavButton({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: AnimatedContainer(
        width: width,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF836EF9) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected ? Colors.white : Colors.white54,
                    size: 22,
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: selected
                          ? Row(
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(width: 0, height: 16),
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
