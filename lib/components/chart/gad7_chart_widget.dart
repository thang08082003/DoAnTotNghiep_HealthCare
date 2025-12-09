import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/anxiety_risk_model.dart';
import '../../viewmodels/anxiety_risk/anxiety_risk_state.dart';

/// Widget biểu đồ GAD-7 có thể tái sử dụng
class GAD7ChartWidget extends StatelessWidget {
  final List<AnxietyRisk> assessments;
  final String title;
  final bool showLegend;
  final TimeRange timeRange;

  const GAD7ChartWidget({
    super.key,
    required this.assessments,
    required this.timeRange,
    this.title = 'Biểu đồ điểm GAD-7',
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showLegend) _buildLegend(),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(height: 200, child: LineChart(_buildChartData(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(Colors.green, 'Tốt'),
        const SizedBox(width: 6),
        _buildLegendItem(Colors.orange, 'TB'),
        const SizedBox(width: 6),
        _buildLegendItem(Colors.red, 'Cao'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }

  LineChartData _buildChartData(BuildContext context) {
    // Xử lý dữ liệu theo timeRange
    final List<AnxietyRisk> dataToDisplay;

    if (timeRange == TimeRange.day) {
      // Hiển thị tất cả các lần đánh giá trong ngày
      dataToDisplay = assessments.reversed.toList();
    } else if (timeRange == TimeRange.week) {
      // Nhóm theo ngày và tính trung bình cho tuần
      dataToDisplay = _groupByDayAndAverage(assessments);
    } else {
      // Tháng: tính trung bình cả tháng (1 điểm duy nhất)
      dataToDisplay = _calculateMonthlyAverage(assessments);
    }

    final spots = dataToDisplay.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.score.toDouble());
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 3,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: timeRange == TimeRange.week ? 45 : 30,
            interval: _getXAxisInterval(),
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= dataToDisplay.length)
                return const SizedBox();
              final assessment = dataToDisplay[value.toInt()];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatXAxisLabel(assessment.createdAt),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 3,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              // Hiển thị 0, 3, 6, 9, 12, 15, 18, 21
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 12),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      minX: 0,
      maxX: (dataToDisplay.length - 1).toDouble(),
      minY: 0,
      maxY: 21,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).primaryColor,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              Color color;
              if (spot.y <= 4) {
                color = Colors.green;
              } else if (spot.y <= 14) {
                color = Colors.orange;
              } else {
                color = Colors.red;
              }
              return FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Theme.of(context).primaryColor.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final assessment = dataToDisplay[spot.x.toInt()];
              return LineTooltipItem(
                '${DateFormat('dd/MM HH:mm').format(assessment.createdAt)}\n'
                'Điểm: ${spot.y.toInt()}/21\n'
                '${assessment.levelDescription}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  /// Tính interval cho trục X để tránh tràn nhãn
  double _getXAxisInterval() {
    if (assessments.isEmpty) return 1;

    switch (timeRange) {
      case TimeRange.day:
        // Hiển thị tối đa 6-8 nhãn giờ
        final count = assessments.length;
        if (count <= 6) return 1;
        return (count / 6).ceilToDouble();

      case TimeRange.week:
        // Hiển thị tối đa 7 nhãn (mỗi ngày)
        return 1;

      case TimeRange.month:
        // Chỉ có 1 điểm (trung bình cả tháng)
        return 1;
    }
  }

  /// Tính điểm trung bình của cả tháng
  List<AnxietyRisk> _calculateMonthlyAverage(List<AnxietyRisk> assessments) {
    if (assessments.isEmpty) return [];

    final avgScore =
        assessments.map((a) => a.score).reduce((a, b) => a + b) ~/
        assessments.length;

    // Tạo 1 AnxietyRisk duy nhất đại diện cho trung bình cả tháng
    return [
      AnxietyRisk(
        id: 'avg_month',
        userId: assessments.first.userId,
        score: avgScore,
        level: AnxietyRisk.calculateLevel(avgScore),
        answers: assessments.first.answers,
        createdAt: assessments.first.createdAt,
      ),
    ];
  }

  /// Nhóm các assessment theo ngày và tính điểm trung bình
  List<AnxietyRisk> _groupByDayAndAverage(List<AnxietyRisk> assessments) {
    if (assessments.isEmpty) return [];

    // Map để lưu các assessment theo ngày
    final Map<String, List<AnxietyRisk>> groupedByDay = {};

    for (final assessment in assessments) {
      final dateKey = DateFormat('yyyy-MM-dd').format(assessment.createdAt);
      groupedByDay.putIfAbsent(dateKey, () => []);
      groupedByDay[dateKey]!.add(assessment);
    }

    // Tính trung bình cho mỗi ngày và tạo AnxietyRisk mới
    final List<AnxietyRisk> dailyAverages = [];

    for (final entry in groupedByDay.entries) {
      final dayAssessments = entry.value;
      final avgScore =
          dayAssessments.map((a) => a.score).reduce((a, b) => a + b) ~/
          dayAssessments.length;

      // Tạo AnxietyRisk đại diện cho trung bình ngày đó
      // Sử dụng thời gian của lần đánh giá đầu tiên trong ngày
      dailyAverages.add(
        AnxietyRisk(
          id: 'avg_${entry.key}',
          userId: dayAssessments.first.userId,
          score: avgScore,
          level: AnxietyRisk.calculateLevel(avgScore),
          answers: dayAssessments.first.answers,
          createdAt: dayAssessments.first.createdAt,
        ),
      );
    }

    // Sắp xếp theo thời gian và đảo ngược để giống với logic ban đầu
    dailyAverages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return dailyAverages.reversed.toList();
  }

  /// Format nhãn trục X theo timeRange
  String _formatXAxisLabel(DateTime dateTime) {
    switch (timeRange) {
      case TimeRange.day:
        // Hiển thị giờ: 08:00, 14:30
        return DateFormat('HH:mm').format(dateTime);

      case TimeRange.week:
        // Hiển thị thứ và ngày: T2 01/12
        final weekday = _getVietnameseWeekday(dateTime.weekday);
        final day = DateFormat('dd/MM').format(dateTime);
        return '$weekday\n$day';

      case TimeRange.month:
        // Hiển thị ngày tháng: 01/12
        return DateFormat('dd/MM').format(dateTime);
    }
  }

  /// Lấy tên thứ tiếng Việt
  String _getVietnameseWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return '';
    }
  }
}
