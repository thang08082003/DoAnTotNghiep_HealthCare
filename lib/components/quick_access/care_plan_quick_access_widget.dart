import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../screens/care_plan/care_plan_screen.dart';

class CarePlanQuickAccessWidget extends StatelessWidget {
  const CarePlanQuickAccessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CarePlanScreen()));
      },
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          // Compact mode when tiles are short, to avoid vertical overflow
          final compact = h < 80;
          final ultraCompact = h < 66;
          final pad = ultraCompact ? 8.0 : (compact ? 10.0 : 16.0);
          final iconSize = ultraCompact ? 16.0 : (compact ? 18.0 : 22.0);
          final gap1 = ultraCompact ? 4.0 : (compact ? 6.0 : 8.0);
          final gap2 = compact ? 2.0 : 4.0;
          final titleStyle = TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: ultraCompact ? 12 : (compact ? 13 : 14),
            height: ultraCompact ? 1.1 : (compact ? 1.15 : 1.2),
            color: AppColors.textPrimary,
          );
          final subtitleStyle = TextStyle(
            fontSize: compact ? 11 : 12,
            height: compact ? 1.1 : 1.2,
            color: AppColors.textSecondary,
          );

          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calendar_month, color: Colors.blue, size: iconSize),
                SizedBox(height: gap1),
                Text(
                  'Kế hoạch chăm sóc',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (!ultraCompact) ...[
                  SizedBox(height: gap2),
                  Text(
                    'Lịch trình & chăm sóc',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
