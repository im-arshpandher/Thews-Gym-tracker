import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;
  final String unit;

  const PlateCalculatorSheet({
    super.key,
    this.initialWeight = 60.0,
    this.unit = 'kg',
  });

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late double _targetWeight;
  late String _unit;
  late double _barWeight;

  static final Map<double, Color> _kgPlateColors = {
    25.0: const Color(0xFFE53935), // Red
    20.0: const Color(0xFF1E88E5), // Blue
    15.0: const Color(0xFFFDD835), // Yellow
    10.0: const Color(0xFF43A047), // Green
    5.0: const Color(0xFFFAFAFA), // White
    2.5: const Color(0xFF212121), // Black
    1.25: const Color(0xFF9E9E9E), // Silver
  };

  static final Map<double, Color> _lbPlateColors = {
    45.0: const Color(0xFF1E88E5), // Blue
    35.0: const Color(0xFFFDD835), // Yellow
    25.0: const Color(0xFF43A047), // Green
    10.0: const Color(0xFFFAFAFA), // White
    5.0: const Color(0xFF212121), // Black
    2.5: const Color(0xFF9E9E9E), // Silver
  };

  @override
  void initState() {
    super.initState();
    _targetWeight = widget.initialWeight;
    _unit = widget.unit;
    _barWeight = _unit == 'kg' ? 20.0 : 45.0;
  }

  Map<double, int> _calculatePlatesPerSide() {
    double weightNeededPerSide = (_targetWeight - _barWeight) / 2;
    if (weightNeededPerSide <= 0) return {};

    final Map<double, int> plateCounts = {};
    final availablePlates = _unit == 'kg'
        ? _kgPlateColors.keys
        : _lbPlateColors.keys;

    for (final plate in availablePlates) {
      if (weightNeededPerSide >= plate) {
        final count = (weightNeededPerSide / plate).floor();
        plateCounts[plate] = count;
        weightNeededPerSide -= (count * plate);
        weightNeededPerSide = double.parse(
          weightNeededPerSide.toStringAsFixed(2),
        );
      }
    }
    return plateCounts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plateMap = _calculatePlatesPerSide();
    final weightNeededPerSide = ((_targetWeight - _barWeight) / 2).clamp(
      0.0,
      999.0,
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.lightSurfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle & Title
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            color: isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PLATE CALCULATOR',
                            style: AppTypography.headlineSm(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Target Weight Control Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.lightSurfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkOutline.withValues(alpha: 0.3)
                            : AppColors.lightOutline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL TARGET WEIGHT',
                          style: AppTypography.labelCaps(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _targetWeight % 1 == 0
                                  ? _targetWeight.toInt().toString()
                                  : _targetWeight.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _unit.toUpperCase(),
                              style: AppTypography.headlineSm(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quick Adjust Buttons
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildAdjustButton('-10', -10),
                              _buildAdjustButton('-2.5', -2.5),
                              _buildAdjustButton('+2.5', 2.5),
                              _buildAdjustButton('+10', 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Barbell Weight Selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BAR WEIGHT',
                              style: AppTypography.labelCaps(),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<double>(
                              initialValue: _barWeight,
                              isDense: true,
                              borderRadius: BorderRadius.circular(16),
                              dropdownColor: isDark
                                  ? AppColors.darkSurfaceContainerHigh
                                  : AppColors.lightSurfaceContainerLowest,
                              elevation: 4,
                              icon: Icon(
                                Icons.arrow_drop_down_circle_outlined,
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                                size: 18,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: _unit == 'kg' ? 20.0 : 45.0,
                                  child: Text(
                                    _unit == 'kg'
                                        ? '20 kg (Olympic)'
                                        : '45 lb (Olympic)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _unit == 'kg' ? 15.0 : 35.0,
                                  child: Text(
                                    _unit == 'kg'
                                        ? '15 kg (Women)'
                                        : '35 lb (Women)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _unit == 'kg' ? 10.0 : 25.0,
                                  child: Text(
                                    _unit == 'kg'
                                        ? '10 kg (EZ Bar)'
                                        : '25 lb (EZ Bar)',
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: 0.0,
                                  child: Text('0 (No Bar)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _barWeight = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WEIGHT PER SIDE',
                              style: AppTypography.labelCaps(),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkOutline
                                      : AppColors.lightOutline,
                                ),
                              ),
                              child: Text(
                                '${weightNeededPerSide % 1 == 0 ? weightNeededPerSide.toInt() : weightNeededPerSide.toStringAsFixed(2)} $_unit',
                                style: AppTypography.bodyLg(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'EACH SIDE PLATES BREAKDOWN',
                    style: AppTypography.labelCaps(),
                  ),
                  const SizedBox(height: 12),

                  // Visual Barbell Sleeve Preview
                  Container(
                    height: 70,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Barbell shaft end
                        Container(
                          width: 24,
                          height: 16,
                          color: Colors.grey.shade600,
                        ),
                        // Sleeve collar
                        Container(
                          width: 12,
                          height: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        // Plates stacked
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: plateMap.entries.expand((entry) {
                                final plateWeight = entry.key;
                                final count = entry.value;
                                final plateColor =
                                    (_unit == 'kg'
                                        ? _kgPlateColors[plateWeight]
                                        : _lbPlateColors[plateWeight]) ??
                                    Colors.grey;

                                return List.generate(count, (index) {
                                  final height =
                                      (30.0 +
                                              (plateWeight /
                                                      (_unit == 'kg'
                                                          ? 25.0
                                                          : 45.0)) *
                                                  30.0)
                                          .clamp(24.0, 60.0);
                                  return Container(
                                    margin: const EdgeInsets.only(right: 3),
                                    width: 14,
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: plateColor,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: Colors.black45,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        plateWeight % 1 == 0
                                            ? plateWeight.toInt().toString()
                                            : plateWeight.toString(),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              plateColor.computeLuminance() >
                                                  0.5
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                });
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Detailed Plates List
                  Expanded(
                    child: plateMap.isEmpty
                        ? Center(
                            child: Text(
                              _targetWeight < _barWeight
                                  ? 'Target weight is less than bar weight'
                                  : 'No extra plates needed',
                              style: AppTypography.bodyMd(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          )
                        : ListView(
                            children: plateMap.entries.map((entry) {
                              final plateWeight = entry.key;
                              final count = entry.value;
                              final plateColor =
                                  (_unit == 'kg'
                                      ? _kgPlateColors[plateWeight]
                                      : _lbPlateColors[plateWeight]) ??
                                  Colors.grey;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: plateColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${plateWeight % 1 == 0 ? plateWeight.toInt() : plateWeight} $_unit plate',
                                      style: AppTypography.bodyLg(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkSurfaceContainerHigh
                                            : AppColors
                                                  .lightSurfaceContainerLow,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '× $count',
                                        style: AppTypography.headlineSm(
                                          color: isDark
                                              ? AppColors.primaryVolt
                                              : AppColors.lightPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustButton(String label, double delta) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _targetWeight = (_targetWeight + delta).clamp(0.0, 500.0);
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
