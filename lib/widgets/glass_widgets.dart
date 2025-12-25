import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.05,
    this.color = Colors.white,
    this.borderRadius,
    this.border,
    this.margin,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              border: border ?? Border.all(color: color.withOpacity(0.1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final IconData? icon;
  final bool isLoading;
  final double fontSize;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = const Color(0xFF4D96FF),
    this.icon,
    this.isLoading = false,
    this.fontSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: fontSize + 4),
                    const SizedBox(width: 8),
                  ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
class GlassConfirmationDialog extends StatelessWidget {
  final String title;
  final List<Map<String, String>> items; // [{label: 'Scrip', value: 'NIFTY 24000 CE'}, {label: 'Action', value: 'BUY'}]
  final VoidCallback onConfirm;
  final String confirmLabel;
  final bool isDestructive;

  const GlassConfirmationDialog({
    super.key,
    required this.title,
    required this.items,
    required this.onConfirm,
    this.confirmLabel = 'CONFIRM',
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        opacity: 0.1,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: isDestructive ? const Color(0xFFFF5F5F) : Colors.orangeAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: items.map((item) {
                  final isLast = items.last == item;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['label'] ?? '',
                          style: TextStyle(
                            color: Colors.blueGrey.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['value'] ?? '',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: (item['label'] == 'Action' || item['label'] == 'Type')
                                  ? (item['value'] == 'BUY'
                                      ? const Color(0xFF00D97E)
                                      : const Color(0xFFFF5F5F))
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: (item['label'] == 'Price') ? 'monospace' : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeonButton(
                    label: confirmLabel,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    color: isDestructive ? const Color(0xFFFF5F5F) : const Color(0xFF00D97E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
