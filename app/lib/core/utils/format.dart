import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:symbians/core/theme/theme.dart';

final _points = NumberFormat('#,##0');
final _usd = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

String formatPoints(int points) => _points.format(points);

String formatSignedPoints(int points) =>
    '${points > 0 ? '+' : points < 0 ? '−' : ''}${_points.format(points.abs())}';

/// Formats a fraction (0.0125) as a percentage ("+1.25%").
String formatPct(double fraction, {bool signed = true, int decimals = 2}) {
  final v = fraction * 100;
  final sign = v < 0 ? '−' : (signed && v > 0 ? '+' : '');
  return '$sign${v.abs().toStringAsFixed(decimals)}%';
}

String formatUsd(double amount) => _usd.format(amount);

String formatShares(double shares) =>
    shares.toStringAsFixed(shares < 1 ? 4 : 2);

String shortAddress(String address) => address.length <= 10
    ? address
    : '${address.substring(0, 4)}…${address.substring(address.length - 4)}';

/// "02:14:09" under a day, "3d 4h" beyond.
String formatCountdown(Duration d) {
  if (d.isNegative) return '00:00:00';
  if (d.inHours >= 24) return '${d.inDays}d ${d.inHours % 24}h';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

Color pnlColor(num value) => value > 0
    ? AppColors.success
    : value < 0
        ? AppColors.error
        : AppColors.textSecondary;

/// User-facing text for an exception thrown by a repository.
String errorText(Object error) => switch (error) {
      StateError(:final message) => message,
      _ => error.toString(),
    };
