import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MuscleGroupIcon extends StatelessWidget {
  final String muscleGroup;
  final double size;
  final bool? isDark;

  const MuscleGroupIcon({
    super.key,
    required this.muscleGroup,
    this.size = 44,
    this.isDark,
  });

  static String getSvgString(String group, {bool isDark = true}) {
    final normalized = group.toLowerCase().trim();
    switch (normalized) {
      case 'chest':
        final bg = isDark ? '#2C1A14' : '#FFEBE0';
        final stroke = isDark ? '#FF5722' : '#D84315';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M35 30 Q50 27 65 30" opacity="0.5" stroke-width="3.5" />
    <path d="M50 35 Q28 35 23 55 Q35 76 50 76 Q65 76 77 55 Q72 35 50 35 Z" />
    <path d="M50 35 L50 72" stroke-width="4.5" />
    <path d="M34 46 Q50 42 66 46" opacity="0.6" stroke-width="3" />
    <path d="M37 59 Q50 56 63 59" opacity="0.6" stroke-width="3" />
  </g>
</svg>''';

      case 'back':
        final bg = isDark ? '#1A2421' : '#E8F5E9';
        final stroke = isDark ? '#4CAF50' : '#1B5E20';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M40 23 L60 23" stroke-width="4" opacity="0.7" />
    <path d="M28 34 C18 46 32 76 50 86 C68 76 82 46 72 34 Z" />
    <path d="M28 34 Q50 24 72 34" />
    <path d="M50 28 L50 76" opacity="0.7" stroke-width="4" />
    <path d="M38 46 Q50 43 62 46" opacity="0.6" stroke-width="3" />
    <path d="M40 57 Q50 54 60 57" opacity="0.6" stroke-width="3" />
  </g>
</svg>''';

      case 'legs':
        final bg = isDark ? '#1A202C' : '#E3F2FD';
        final stroke = isDark ? '#2196F3' : '#0D47A1';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M50 22 L50 44" stroke-width="6" />
    <path d="M50 44 L28 50 M50 44 L72 50" stroke-width="6" />
    <path d="M28 50 L34 76 M72 50 L66 76" stroke-width="6" />
    <path d="M22 76 L44 76 M56 76 L78 76" opacity="0.8" stroke-width="4.5" />
    <circle cx="28" cy="50" r="3.5" fill="$stroke" stroke="none" />
    <circle cx="72" cy="50" r="3.5" fill="$stroke" stroke="none" />
  </g>
</svg>''';

      case 'shoulders':
        final bg = isDark ? '#2D2010' : '#FFF8E1';
        final stroke = isDark ? '#FFC107' : '#E65100';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="50" cy="32" r="11" stroke-width="5" />
    <path d="M24 52 Q50 36 76 52" stroke-width="6" />
    <path d="M24 52 C18 64 25 76 34 76 L66 76 C75 76 82 64 76 52 Z" stroke-width="5" />
    <path d="M30 52 L22 66 M70 52 L78 66" opacity="0.7" stroke-width="4" />
  </g>
</svg>''';

      case 'arms':
      case 'biceps':
      case 'triceps':
        final bg = isDark ? '#2D1A2D' : '#FCE4EC';
        final stroke = isDark ? '#E91E63' : '#880E4F';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M32 44 Q22 44 22 60 Q22 76 38 76" stroke-width="6" />
    <path d="M32 44 L44 56 L38 76" stroke-width="5" />
    <path d="M68 44 Q78 44 78 60 Q78 76 62 76" stroke-width="6" />
    <path d="M68 44 L56 56 L62 76" stroke-width="5" />
    <path d="M38 76 L62 76" stroke-width="4" opacity="0.6" />
    <circle cx="34" cy="50" r="4" fill="$stroke" stroke="none" />
    <circle cx="66" cy="50" r="4" fill="$stroke" stroke="none" />
  </g>
</svg>''';

      case 'forearms':
        final bg = isDark ? '#2D2710' : '#FFFDE7';
        final stroke = isDark ? '#FFC107' : '#F57F17';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M38 28 L38 72 M62 28 L62 72" stroke-width="6" />
    <path d="M30 40 L70 40 M30 60 L70 60" stroke-width="5" />
    <circle cx="38" cy="50" r="4" fill="$stroke" stroke="none" />
    <circle cx="62" cy="50" r="4" fill="$stroke" stroke="none" />
  </g>
</svg>''';

      case 'neck':
        final bg = isDark ? '#102D29' : '#E0F2F1';
        final stroke = isDark ? '#00BFA5' : '#004D40';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="50" cy="30" r="10" stroke-width="5" />
    <path d="M36 50 C36 44 42 42 50 42 C58 42 64 44 64 50 L72 74 L28 74 Z" stroke-width="5" />
  </g>
</svg>''';

      case 'core':
      case 'abs':
      case 'core / abs':
        final bg = isDark ? '#1A1A2D' : '#F3E5F5';
        final stroke = isDark ? '#9C27B0' : '#4A148C';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <rect x="36" y="28" width="28" height="44" rx="6" stroke-width="4.5" />
    <path d="M36 42 H64 M36 57 H64" stroke-width="4" />
    <path d="M50 28 V72" stroke-width="4" />
  </g>
</svg>''';

      case 'cardio':
        final bg = isDark ? '#1A2D2D' : '#E0F7FA';
        final stroke = isDark ? '#00BCD4' : '#006064';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M18 84 L82 84" stroke-width="4" opacity="0.5" />
    <circle cx="52" cy="24" r="7" stroke-width="5" />
    <path d="M52 31 L46 54" stroke-width="6" />
    <path d="M46 54 L62 64 L52 84" stroke-width="5.5" />
    <path d="M46 54 L30 68 L40 84" opacity="0.7" stroke-width="4.5" />
    <path d="M50 38 L68 44 L62 56" stroke-width="5" />
    <path d="M50 38 L36 42 L30 56" opacity="0.7" stroke-width="4.5" />
  </g>
</svg>''';

      default:
        final bg = isDark ? '#2D2D2D' : '#F1F8D0';
        final stroke = isDark ? '#C3F400' : '#356500';
        return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="$bg" />
  <g fill="none" stroke="$stroke" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M25 40 H75 L75 60 H25 Z" rx="4" stroke-width="5" />
    <path d="M35 30 V70 M65 30 V70" stroke-width="6" />
    <path d="M22 35 V65 M78 35 V65" stroke-width="5" />
  </g>
</svg>''';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final svgCode = getSvgString(muscleGroup, isDark: effectiveIsDark);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: SvgPicture.string(
          svgCode,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
