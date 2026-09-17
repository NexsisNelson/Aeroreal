import 'package:flutter/material.dart';

/// Shows a confirmation dialog before a transaction.
/// Returns `true` if the user confirms, `false` otherwise.
Future<bool> showConfirmTransaction({
  required BuildContext context,
  required String title,
  required String description,
  required List<(String, String)> details,
  String confirmLabel = 'Confirm',
  Color confirmColor = const Color(0xFF836EF9),
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1625),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          ...details.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d.$1,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    Flexible(
                      child: Text(
                        d.$2,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFF6B35), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This transaction cannot be undone.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
