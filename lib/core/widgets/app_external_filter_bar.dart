import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppExternalFilterBar extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final bool showApplyButton;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final bool isBusy;

  const AppExternalFilterBar({
    super.key,
    this.title = 'Filter Data',
    required this.isExpanded,
    required this.onToggle,
    required this.onReset,
    required this.onApply,
    this.showApplyButton = false,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 8),
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 760;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                _FilterTitle(title: title),
                const SizedBox(height: 12),
                _FilterActions(
                  isExpanded: isExpanded,
                  onToggle: onToggle,
                  onReset: onReset,
                  onApply: onApply,
                  showApplyButton: showApplyButton,
                  isBusy: isBusy,
                  isMobile: true,
                ),
              ] else
                Row(
                  children: [
                    Expanded(child: _FilterTitle(title: title)),
                    const SizedBox(width: 16),
                    _FilterActions(
                      isExpanded: isExpanded,
                      onToggle: onToggle,
                      onReset: onReset,
                      onApply: onApply,
                      showApplyButton: showApplyButton,
                      isBusy: isBusy,
                      isMobile: false,
                    ),
                  ],
                ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < children.length; i++) ...[
                              children[i],
                              if (i < children.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        )
                      : Wrap(spacing: 12, runSpacing: 12, children: children),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AppExternalFilterField extends StatelessWidget {
  final String label;
  final Widget child;
  final double minWidth;

  const AppExternalFilterField({
    super.key,
    required this.label,
    required this.child,
    this.minWidth = 240,
  });

  @override
  Widget build(BuildContext context) {
    // Inside a Wrap (mobile disabled), constraints are unbounded → use minWidth.
    // Inside a Column with stretch (mobile), constraints are bounded → fill width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth ? double.infinity : minWidth;
        return SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        );
      },
    );
  }
}

InputDecoration appExternalFilterDecoration({
  required String hintText,
  IconData? icon,
}) {
  return InputDecoration(
    hintText: hintText,
    isDense: true,
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 18, color: AppColors.primary),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _FilterTitle extends StatelessWidget {
  final String title;

  const _FilterTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Perubahan filter langsung memperbarui data.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FilterActions extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final bool showApplyButton;
  final bool isBusy;
  final bool isMobile;

  const _FilterActions({
    required this.isExpanded,
    required this.onToggle,
    required this.onReset,
    required this.onApply,
    required this.showApplyButton,
    required this.isBusy,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      OutlinedButton(
        onPressed: isBusy ? null : onReset,
        child: const Text('Reset'),
      ),
      if (showApplyButton)
        FilledButton(
          onPressed: isBusy ? null : onApply,
          child: const Text('Terapkan'),
        ),
      FilledButton.tonal(
        onPressed: onToggle,
        child: Text(isExpanded ? 'Hide Filter' : 'Show Filter'),
      ),
    ];

    if (isMobile) {
      return Wrap(spacing: 8, runSpacing: 8, children: children);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: children,
    );
  }
}
