import 'package:flutter/material.dart';

import '../screens/legal_webview_screen.dart';

const String kPrivacyPolicyUrl = 'https://pyrofallridge.com/privacy-policy.html';
const String kSupportUrl = 'https://pyrofallridge.com/support.html';

/// Small, unobtrusive Privacy Policy / Support links, required so both the
/// game and store reviewers can always reach these pages from inside the
/// app. Intentionally not part of the core gameplay loop.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegalLink(
          label: 'Privacy Policy',
          onTap: () => _open(context, 'Privacy Policy', kPrivacyPolicyUrl),
        ),
        Container(
          width: 1,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: Colors.white.withValues(alpha: 0.25),
        ),
        _LegalLink(
          label: 'Support',
          onTap: () => _open(context, 'Support', kSupportUrl),
        ),
      ],
    );
  }

  void _open(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalWebViewScreen(title: title, url: url),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
