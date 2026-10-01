import 'package:flutter/widgets.dart';

class AppError {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppError({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
}

class ErrorMapper {
  static AppError map(dynamic error) {
    final raw = error?.toString() ?? 'unknown error';
    final lower = raw.toLowerCase();

    if (lower.contains('insufficient') ||
        lower.contains('erc20insufficientbalance')) {
      return const AppError(
        title: 'Insufficient balance',
        message:
            'You don\'t have enough tokens to complete this transaction. Check your AREAL balance and try again.',
      );
    }

    if (lower.contains('erc20insufficientallowance') ||
        lower.contains('allowance')) {
      return const AppError(
        title: 'Approval required',
        message:
            'The app needs permission to spend your tokens. Approve the transaction and try again.',
      );
    }

    if (lower.contains('not whitelisted') ||
        lower.contains('notwhitelisted') ||
        lower.contains('whitelist')) {
      return const AppError(
        title: 'Identity verification required',
        message:
            'This asset requires KYC verification. Complete your verification and try again.',
      );
    }

    if (lower.contains('already claimed') ||
        lower.contains('cooldown') ||
        lower.contains('claim_cooldown')) {
      return const AppError(
        title: 'Already claimed',
        message:
            'You\'ve already claimed from this faucet recently. Please try again later.',
      );
    }

    if (lower.contains('insufficient balance for gas') ||
        lower.contains('signer had insufficient balance') ||
        lower.contains('gas')) {
      return const AppError(
        title: 'Not enough MON for gas',
        message:
            'You need a small amount of MON to pay for network fees. Please get some MON and try again.',
      );
    }

    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('network')) {
      return const AppError(
        title: 'Network unavailable',
        message:
            'We couldn\'t reach the Monad network. Check your internet connection and try again.',
      );
    }

    if (lower.contains('nonce')) {
      return const AppError(
        title: 'Transaction in progress',
        message:
            'A pending transaction is already running. Wait a moment, then try again.',
      );
    }

    if (lower.contains('transaction reverted') ||
        lower.contains('execution reverted') ||
        lower.contains('revert')) {
      return const AppError(
        title: 'Transaction failed',
        message:
            'Something went wrong with this transaction. Make sure you have sufficient balance and try again.',
      );
    }

    if (lower.contains('privy') || lower.contains('signing failed')) {
      return const AppError(
        title: 'Signature failed',
        message:
            'We couldn\'t sign the transaction. Check your wallet connection and try again.',
      );
    }

    return const AppError(
      title: 'Something went wrong',
      message: 'We ran into an unexpected issue. Please try again in a moment.',
    );
  }

  static String shortMessage(dynamic error) {
    final appError = map(error);
    return '${appError.title}: ${appError.message}';
  }
}
