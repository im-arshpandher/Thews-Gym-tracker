import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Standalone widget for exercise progress analytics chart with metric selector.
class ProgressAnalyticsCard extends StatefulWidget {
  final List<ExerciseProgressPoint> points;

  const ProgressAnalyticsCard({super.key, required this.points});

  @override
  State<ProgressAnalyticsCard> createState() => _ProgressAnalyticsCardState();
}

class _ProgressAnalyticsCardState extends State<ProgressAnalyticsCard> {
  String _selectedMetric = '1RM';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = widget.points;

    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.lightSurfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 36,
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.lightOutlineVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No workout history recorded yet for this exercise.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final max1RM = points.fold<double>(
      0,
      (prev, p) => p.estimated1RM > prev ? p.estimated1RM : prev,
    );
    final maxWeight = points.fold<double>(
      0,
      (prev, p) => p.maxWeight > prev ? p.maxWeight : prev,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.3)
              : AppColors.lightOutline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insights,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROGRESS TRENDS',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMetricChip('1RM', _selectedMetric == '1RM', isDark),
                  const SizedBox(width: 4),
                  _buildMetricChip(
                    'Max Weight',
                    _selectedMetric == 'Max Weight',
                    isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildMetricChip(
                    'Volume',
                    _selectedMetric == 'Volume',
                    isDark,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // High Level PR Summary Banner
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  'EST. 1RM PR',
                  '${max1RM.toStringAsFixed(1)} kg',
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryBox(
                  'MAX WEIGHT',
                  '${maxWeight.toStringAsFixed(1)} kg',
                  isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Interactive fl_chart LineChart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX:
                    (points.length - 1).toDouble() > 0
                        ? (points.length - 1).toDouble()
                        : 1.0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < points.length) {
                          final dt = points[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${dt.month}/${dt.day}',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary,
                          strokeWidth: 2,
                          strokeColor: isDark ? Colors.black : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color:
                          (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.18),
                    ),
                    spots: points.asMap().entries.map((e) {
                      final idx = e.key.toDouble();
                      final p = e.value;
                      double val = p.estimated1RM;
                      if (_selectedMetric == 'Max Weight') val = p.maxWeight;
                      if (_selectedMetric == 'Volume') val = p.totalVolume;
                      return FlSpot(idx, val);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () => setState(() => _selectedMetric = label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
              : (isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.lightSurfaceContainerHigh),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isDark ? AppColors.primaryVoltOn : Colors.white)
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ).copyWith(fontSize: 9),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.headlineSm(
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
