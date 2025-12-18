import 'package:flutter/material.dart';
import '../model/world_state.dart';

class MapWidget extends StatefulWidget {
  final WorldState worldState;
  final void Function(int x, int y)? onTileTap;

  static const double labelSize = 24.0;

  const MapWidget({super.key, required this.worldState, this.onTileTap});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  MouseCursor _cursor = SystemMouseCursors.basic;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = _calculateTileSize(constraints);

        return MouseRegion(
          cursor: _cursor,
          onHover: (event) {
            final x =
                ((event.localPosition.dx - MapWidget.labelSize) / tileSize)
                    .floor();
            final y =
                ((event.localPosition.dy - MapWidget.labelSize) / tileSize)
                    .floor();

            if (x >= 0 &&
                x < widget.worldState.width &&
                y >= 0 &&
                y < widget.worldState.height) {
              final hasUnit = widget.worldState.units.any(
                (u) => u.x == x && u.y == y,
              );
              final hasStructure = widget.worldState.structures.any(
                (s) => s.x == x && s.y == y,
              );

              final newCursor = (hasUnit || hasStructure)
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic;

              if (newCursor != _cursor) {
                setState(() {
                  _cursor = newCursor;
                });
              }
            } else {
              if (_cursor != SystemMouseCursors.basic) {
                setState(() {
                  _cursor = SystemMouseCursors.basic;
                });
              }
            }
          },
          child: GestureDetector(
            onTapUp: (details) {
              if (widget.onTileTap != null) {
                final x =
                    ((details.localPosition.dx - MapWidget.labelSize) /
                            tileSize)
                        .floor();
                final y =
                    ((details.localPosition.dy - MapWidget.labelSize) /
                            tileSize)
                        .floor();
                if (x >= 0 &&
                    x < widget.worldState.width &&
                    y >= 0 &&
                    y < widget.worldState.height) {
                  widget.onTileTap!(x, y);
                }
              }
            },
            child: CustomPaint(
              size: Size(
                widget.worldState.width * tileSize + MapWidget.labelSize,
                widget.worldState.height * tileSize + MapWidget.labelSize,
              ),
              painter: MapPainter(
                worldState: widget.worldState,
                tileSize: tileSize,
                labelSize: MapWidget.labelSize,
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateTileSize(BoxConstraints constraints) {
    // Subtract label size from available space before calculating tile size
    final availableWidth = constraints.maxWidth - MapWidget.labelSize;
    final availableHeight = constraints.maxHeight - MapWidget.labelSize;

    if (availableWidth <= 0 || availableHeight <= 0) return 10.0; // Fallback

    final widthPerTile = availableWidth / widget.worldState.width;
    final heightPerTile = availableHeight / widget.worldState.height;
    return widthPerTile < heightPerTile ? widthPerTile : heightPerTile;
  }
}

class MapPainter extends CustomPainter {
  final WorldState worldState;
  final double tileSize;
  final double labelSize;

  MapPainter({
    required this.worldState,
    required this.tileSize,
    required this.labelSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    // Shift canvas for map
    canvas.save();
    canvas.translate(labelSize, labelSize);

    // Draw Terrain & Grid
    for (int y = 0; y < worldState.height; y++) {
      for (int x = 0; x < worldState.width; x++) {
        final tile = worldState.terrain[y][x];
        switch (tile) {
          case TileType.grass:
            paint.color = Colors.lightGreen;
            break;
          case TileType.water:
            paint.color = Colors.blue;
            break;
          case TileType.mountain:
            paint.color = Colors.grey;
            break;
        }
        canvas.drawRect(
          Rect.fromLTWH(x * tileSize, y * tileSize, tileSize, tileSize),
          paint,
        );

        // Grid lines
        paint.color = Colors.black12;
        paint.style = PaintingStyle.stroke;
        canvas.drawRect(
          Rect.fromLTWH(x * tileSize, y * tileSize, tileSize, tileSize),
          paint,
        );
        paint.style = PaintingStyle.fill;
      }
    }

    // Draw Structures
    for (final struct in worldState.structures) {
      paint.color = struct.type == StructureType.base
          ? Colors.brown
          : Colors.orange;
      canvas.drawRect(
        Rect.fromLTWH(
          struct.x * tileSize + tileSize * 0.1,
          struct.y * tileSize + tileSize * 0.1,
          tileSize * 0.8,
          tileSize * 0.8,
        ),
        paint,
      );
    }

    // Draw Units
    for (final unit in worldState.units) {
      paint.color = Colors.white;
      canvas.drawCircle(
        Offset(
          unit.x * tileSize + tileSize / 2,
          unit.y * tileSize + tileSize / 2,
        ),
        tileSize * 0.3,
        paint,
      );
      paint.color = Colors.black;
      canvas.drawCircle(
        Offset(
          unit.x * tileSize + tileSize / 2,
          unit.y * tileSize + tileSize / 2,
        ),
        tileSize * 0.3,
        paint..style = PaintingStyle.stroke,
      );
      paint.style = PaintingStyle.fill;
    }

    canvas.restore(); // Restore to draw labels in the margins

    // Draw X Axis Labels
    for (int x = 0; x < worldState.width; x++) {
      if (x % 2 != 0 && x != worldState.width - 1 && x != 0) {
        continue; // Skip some labels to avoid crowding?
      }
      // Actually standard 20x20 is dense. Let's label 0, 5, 10, 15... or just all if specific commands needed.
      // Better: Label every 5.
      // Actually, user needs specific coords.
      // How about: Label every 1 but small font?
      // Or: Label every 1 but stagger?
      // Let's try labeling every 2 or 5 unless zoomed in.
      // Given the user wants to identify tiles for input, they need precise numbers.
      // Let's draw every number but small.

      textPainter.text = TextSpan(text: '$x', style: textStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelSize + x * tileSize + (tileSize - textPainter.width) / 2,
          (labelSize - textPainter.height) / 2,
        ),
      );
    }

    // Draw Y Axis Labels
    for (int y = 0; y < worldState.height; y++) {
      textPainter.text = TextSpan(text: '$y', style: textStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (labelSize - textPainter.width) / 2,
          labelSize + y * tileSize + (tileSize - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return true;
  }
}
