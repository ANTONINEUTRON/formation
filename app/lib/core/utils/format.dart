import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/app_log.dart';

/// Points are numeric(10,1): show the decimal only when there is one.
final _points = NumberFormat('#,##0.#');
final _usd = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _shortDate = DateFormat('d MMM');

/// "4 Sep" — compact enough for a leaderboard period chip.
String formatShortDate(DateTime date) => _shortDate.format(date);

/// "1h", "3d" — a league's length, as the creator picked it.
String formatDuration(Duration d) =>
    d.inHours < 24 ? '${d.inHours}h' : '${d.inDays}d';

String formatPoints(num points) => _points.format(points);

String formatSignedPoints(num points) =>
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
/// Shown when we have nothing better to say. Deliberately not the exception.
const _genericError = 'Something went wrong. Please try again.';

/// A short, human sentence for [error], safe to put on screen.
///
/// The full error and its stack trace are logged; only messages we wrote
/// ourselves ever reach the UI. Anything unrecognised becomes a generic line
/// rather than a type-cast message or a socket dump, which tell a player
/// nothing and leak internals.
String errorText(Object error, [StackTrace? stackTrace]) {
  AppLog.error('Surfaced to the user', error, stackTrace);

  return switch (error) {
    // Our own exceptions carry a message written for a player to read.
    AppException(:final message) => message,
    TimeoutException() => 'That took too long. Please try again.',
    _ => _genericError,
  };
}
