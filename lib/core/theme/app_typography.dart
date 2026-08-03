import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Typography System as defined in size_standardization.md
/// Allowed font sizes: 11, 12, 13, 14, 16, 18, 22, 26, 32 (and displayMetrics 32/48)
class AppTypography {
  /// Hero / Display (32px, 700)
  static TextStyle displayHero({Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }

  /// Page Title (26px, 700)
  static TextStyle pageTitle({Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: 26,
      height: 1.20,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }

  /// Section Title (22px, 600)
  static TextStyle sectionTitle({Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  /// Card / Component Title (18px, 600)
  static TextStyle cardTitle({Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: 18,
      height: 1.30,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  /// Large Body (16px, 500)
  static TextStyle bodyLg({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }

  /// Standard Body (14px, 400)
  static TextStyle bodyMd({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  /// Secondary Text (13px, 400)
  static TextStyle secondaryText({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  /// Caption / Metadata (12px, 400)
  static TextStyle bodySm({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      height: 1.30,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  /// Tiny Label (11px, 500)
  static TextStyle tinyLabel({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 11,
      height: 1.20,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }

  /// Label Caps / Category Label (12px, 700)
  static TextStyle labelCaps({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      height: 1.20,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }

  /// Backward Compatibility Helpers
  static TextStyle displayMetrics({Color? color}) => displayHero(color: color);
  static TextStyle headlineLg({Color? color}) => pageTitle(color: color);
  static TextStyle headlineMd({Color? color}) => sectionTitle(color: color);
  static TextStyle headlineSm({Color? color}) => cardTitle(color: color);
}
