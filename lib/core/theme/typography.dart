import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

// Spec section 4 — Typography
// Wordmark: Young Serif
// Headers / display: Syne 700
// Body / UI: Avenir Next Medium (system-ui fallback until licensing confirmed)

// ── Wordmark ──────────────────────────────────────────────────────────────────
final wordmarkLarge = GoogleFonts.youngSerif(
  fontSize: 40,
  color: warmWhite,
);

final wordmarkHeader = GoogleFonts.youngSerif(
  fontSize: 28,
  color: warmWhite,
);

// ── Headers / Display ─────────────────────────────────────────────────────────
final screenTitle = GoogleFonts.syne(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: warmWhite,
);

final rowName = GoogleFonts.syne(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: warmWhite,
);

final pillLabel = GoogleFonts.syne(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: warmWhite,
);

// ── Screen titles (non-Syne) ─────────────────────────────────────────────────
const titleLarge = TextStyle(
  color: warmWhite,
  fontSize: 24,
);

const titleMedium = TextStyle(
  color: warmWhite,
  fontSize: 18,
);

// ── Body / UI ─────────────────────────────────────────────────────────────────
const bodyText = TextStyle(
  color: warmWhite,
  fontSize: 16,
);

final bodySubdued = TextStyle(
  color: warmWhite.withValues(alpha: 0.6),
  fontSize: 14,
);

final bodyDimmed = TextStyle(
  color: warmWhite.withValues(alpha: 0.45),
  fontSize: 13,
);

final bodyFaint = TextStyle(
  color: warmWhite.withValues(alpha: 0.3),
  fontSize: 12,
);

// ── Secondary / timestamps ────────────────────────────────────────────────────
final timestamp = TextStyle(
  fontSize: 12,
  color: warmWhite.withValues(alpha: 0.4),
);

final placeholderText = TextStyle(
  fontSize: 14,
  color: warmWhite.withValues(alpha: 0.4),
);

final searchHint = TextStyle(
  fontSize: 14,
  color: warmWhite.withValues(alpha: 0.3),
);

const activeNow = TextStyle(
  fontSize: 12,
  color: oliveLight,
);

// ── Avatars ───────────────────────────────────────────────────────────────────
// Color comes from the avatar color map — only size/weight shared here
const avatarInitialLarge = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
);

const avatarInitialMini = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w700,
);

// ── Input fields ──────────────────────────────────────────────────────────────
const inputText = TextStyle(
  color: warmWhite,
);

final hintText = TextStyle(
  color: warmWhite.withValues(alpha: 0.5),
);

final inputBorderEnabled = UnderlineInputBorder(
  borderSide: BorderSide(color: warmWhite.withValues(alpha: 0.3)),
);

const inputBorderFocused = UnderlineInputBorder(
  borderSide: BorderSide(color: warmWhite),
);

// ── Error ─────────────────────────────────────────────────────────────────────
const errorText = TextStyle(
  color: errorColor,
  fontSize: 14,
);

// ── Buttons ───────────────────────────────────────────────────────────────────
const buttonLabel = TextStyle(
  color: warmWhite,
);

// ── Invite text ───────────────────────────────────────────────────────────────
final inviteArrow = GoogleFonts.syne(
  fontSize: 13,
  color: warmWhite.withValues(alpha: 0.6),
);

final pendingLabel = TextStyle(
  fontSize: 12,
  color: warmWhite.withValues(alpha: 0.4),
);

// ── Shared decoration ─────────────────────────────────────────────────────────
final listDividerColor = Colors.white.withValues(alpha: 0.06);
