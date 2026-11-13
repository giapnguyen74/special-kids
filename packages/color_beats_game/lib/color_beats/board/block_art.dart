import 'package:flutter/material.dart';

import 'block_board_view.dart';

/// Small picture of colorful pieces (home and level screens), drawn with the same blocks as the board.
class BlockArt extends StatelessWidget {
  const BlockArt({super.key, this.cell = 34});
  final double cell;

  // (row, col, color) on a 4 x 7 canvas.
  static const _cells = [
    // purple T
    (0, 0, 6), (0, 1, 6), (0, 2, 6), (1, 1, 6),
    // yellow square
    (2, 0, 2), (2, 1, 2), (3, 0, 2), (3, 1, 2),
    // cyan L
    (1, 3, 4), (2, 3, 4), (3, 3, 4), (3, 4, 4),
    // red S
    (0, 5, 0), (1, 5, 0), (1, 6, 0), (2, 6, 0),
    // green dot + orange bar
    (2, 2, 3), (3, 5, 1), (3, 6, 1),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: cell * 7,
    height: cell * 4,
    child: CustomPaint(painter: _ArtPainter(cell)),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.cell);
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (r, c, color) in BlockArt._cells) {
      drawBlock(
        canvas,
        Rect.fromLTWH(c * cell, r * cell, cell, cell),
        blockPalette[color],
        shadow: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.cell != cell;
}
