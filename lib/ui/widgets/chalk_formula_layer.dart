import 'package:flutter/material.dart';
import 'package:katex/katex.dart';

import '../theme/palette.dart';

/// Chalk formulas scribbled on the board, rendered with real KaTeX.
/// Positions are normalized fractions of width/height.
const List<(String, double, double)> chalkFormulas = [
  (r'\int_0^\infty e^{-x^2}\,dx = \sqrt{\pi}', 0.08, 0.30),
  (r'a^{2} + b^{2} = c^{2}', 0.66, 0.27),
  (r'P(A \mid B) = \frac{P(B \mid A)\,P(A)}{P(B)}', 0.25, 0.52),
  (r'\zeta(s) = \sum_{n=1}^{\infty} n^{-s}', 0.68, 0.55),
  (r'e^{i\pi} + 1 = 0', 0.10, 0.78),
  (r'F = m \cdot a', 0.58, 0.80),
];

/// Decorative chalk-formula layer. Static content positioned relative to its
/// own bounds; used as a const child so HUD updates never rebuild it (plan
/// section 10).
class ChalkFormulaLayer extends StatelessWidget {
  const ChalkFormulaLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.loose,
          children: [
            for (final (tex, fx, fy) in chalkFormulas)
              Positioned(
                left: fx * w,
                top: fy * h,
                child: Math(tex, color: Palette.ink, fontSize: 17),
              ),
          ],
        );
      },
    );
  }
}
