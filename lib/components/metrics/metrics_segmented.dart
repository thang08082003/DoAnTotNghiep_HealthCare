import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum MetricsRange { day, week, month }

class MetricsSegmented extends StatelessWidget {
  final MetricsRange value;
  final ValueChanged<MetricsRange> onChanged;
  const MetricsSegmented({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segWidth = (constraints.maxWidth / 3).clamp(0.0, double.infinity);
        return SizedBox(
          width: constraints.maxWidth,
          child: CupertinoSegmentedControl<MetricsRange>(
            padding: EdgeInsets.zero,
            groupValue: value,
            children: {
              MetricsRange.day: SizedBox(
                width: segWidth,
                child: const Center(child: Text('Ngày')),
              ),
              MetricsRange.week: SizedBox(
                width: segWidth,
                child: const Center(child: Text('Tuần')),
              ),
              MetricsRange.month: SizedBox(
                width: segWidth,
                child: const Center(child: Text('Tháng')),
              ),
            },
            onValueChanged: onChanged,
          ),
        );
      },
    );
  }
}
