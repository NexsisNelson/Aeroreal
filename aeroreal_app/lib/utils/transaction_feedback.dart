import 'dart:async';

import 'package:flutter/material.dart';

import 'error_mapper.dart';

class TransactionFeedback {
  static bool isConnectionIssue(Object error) {
    if (error is TimeoutException) return true;

    final message = error.toString().toLowerCase();
    return const [
      'connection refused',
      'connection reset',
      'failed host lookup',
      'network is unreachable',
      'socketexception',
      'timed out',
      'timeout',
    ].any(message.contains);
  }

  static void showConnectionToast(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Connection issue. Check your network and try again.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
  }

  static Future<void> showTransactionError(
    BuildContext context, {
    required String functionName,
    required Object error,
  }) {
    final action = functionName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}')
        .trim();
    final title = action.isEmpty
        ? 'Transaction failed'
        : '${action[0].toUpperCase()}${action.substring(1)} failed';
    final mapped = ErrorMapper.map(error);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(mapped.title.isNotEmpty ? mapped.title : title),
        content: Text(mapped.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
