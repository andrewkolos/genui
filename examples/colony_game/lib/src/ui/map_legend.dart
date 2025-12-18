import 'package:flutter/material.dart';

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.lightGreen, 'Grass (Walkable)', isSquare: true),
            _buildLegendItem(Colors.blue, 'Water (Blocked)', isSquare: true),
            _buildLegendItem(Colors.grey, 'Mountain (Blocked)', isSquare: true),
            const Divider(),
            _buildLegendItem(Colors.white, 'Colonist', isCircle: true),
            _buildLegendItem(Colors.brown, 'Base', isSquare: true),
            _buildLegendItem(Colors.orange, 'Farm', isSquare: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isSquare = false, bool isCircle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              border: Border.all(color: Colors.black26),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
