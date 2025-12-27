import 'package:flutter/material.dart';
import 'chart_container.dart';

class ChartWithSummary extends StatelessWidget {
  final String title;
  final Widget chart;
  final double? min;
  final double? max;
  final double? avg;
  final String unit;
  const ChartWithSummary({
    super.key,
    required this.title,
    required this.chart,
    required this.min,
    required this.max,
    required this.avg,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 240, child: chart),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ChartContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('Tối đa', max),
              _summaryItem('Tối thiểu', min),
              _summaryItem('Trung bình', avg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, double? value) {
    final text = value == null ? '-' : '${value.toStringAsFixed(0)} $unit';
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
