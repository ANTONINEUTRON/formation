import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/theme/theme.dart';

/// Opens one of the legal pages in the browser.
Future<void> openLegalPage(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// "By connecting, you agree to the Terms and Privacy Policy." with both
/// names linked to the pages on the landing site.
class LegalLinks extends StatefulWidget {
  const LegalLinks({this.lead = 'By connecting a wallet, you agree to the', super.key});

  /// The words before "Terms", e.g. what the Manager is about to do.
  final String lead;

  @override
  State<LegalLinks> createState() => _LegalLinksState();
}

class _LegalLinksState extends State<LegalLinks> {
  final _terms = TapGestureRecognizer()..onTap = () => openLegalPage(AppConstants.termsUrl);
  final _privacy = TapGestureRecognizer()..onTap = () => openLegalPage(AppConstants.privacyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textMuted,
    );
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
        children: [
          TextSpan(text: '${widget.lead} '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '. Formation is a game, not investment advice.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
