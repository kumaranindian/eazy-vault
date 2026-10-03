import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_spacing.dart';

/// The official multi-color Google "G" mark, inlined as SVG (via the
/// already-declared `flutter_svg` dependency) rather than a Material icon —
/// `Icons.g_mobiledata` doesn't resemble the Google logo at all.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v9h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.16z"/>
  <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.34l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.08h-7.33v5.7C7.46 40.69 15.1 46 24 46z"/>
  <path fill="#FBBC05" d="M11.69 28.16c-.43-1.29-.67-2.67-.67-4.09s.24-2.8.67-4.09v-5.7H4.36A22.07 22.07 0 0 0 2 24c0 3.57.86 6.94 2.36 9.92l7.33-5.76z"/>
  <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.28l6.31-6.31C34.91 4.18 29.93 2 24 2 15.1 2 7.46 7.31 4.36 14.08l7.33 5.7c1.73-5.21 6.58-9.03 12.31-9.03z"/>
</svg>
''';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Sign in with Google',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 20,
            child: SvgPicture.string(_googleLogoSvg),
          ),
          AppSpacing.gapMD,
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
