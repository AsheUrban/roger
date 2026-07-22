import 'package:flutter/material.dart';

// Spec section 4 — UI colors
const charcoal = Color(0xFF1E1D18);
const charcoal2 = Color(0xFF2E2D26);
const warmWhite = Color(0xFFFAFAF5);
const salmon = Color(0xFFFF6B4E);
const oliveDark = Color(0xFF595900);
const oliveLight = Color(0xFFE8E600);

// Error text: warm white at 70% — salmon is reserved for camera actions only
const errorColor = Color(0xB3FAFAF5);

// Destructive actions (leave, delete account) — red, per the mockup. Distinct
// from salmon (camera-only).
const destructive = Color(0xFFFF4444);

// Translucent black backdrop for controls overlaid on the camera surface
// (header circle buttons, recording timer) — the mockup's rgba(0,0,0,0.35).
const overlayScrim = Color(0x59000000);

// Spec section 4 — Avatar color system
// 8 colors: (background, foreground)
// 'Charcoal' is intentionally absent — its background matched the app bg
// (#1E1D18), making the avatar circle invisible against the screen. Any
// existing rows with avatar_color = 'Charcoal' fall back to (charcoal2,
// warmWhite) via the `??` in render sites — visible but neutral.
const avatarColorMap = <String, (Color, Color)>{
  'Deep Red': (Color(0xFF2E0A0A), Color(0xFFFF8A80)),
  'Rust': (Color(0xFF7A3B2E), Color(0xFFFFB8A0)),
  'Deep Ember': (Color(0xFF3D1500), Color(0xFFFF6B4E)),
  'Burnt Orange': (Color(0xFF4A2800), Color(0xFFFFB347)),
  'Salmon': (Color(0xFFFF6B4E), Color(0xFFFFF0ED)),
  'Rose': (Color(0xFFFF5E7A), Color(0xFFFFE8EE)),
  'Olive': (Color(0xFF595900), Color(0xFFE8E600)),
  'Cornflower': (Color(0xFF6395EE), Color(0xFFEDD4FA)),
};

// The note composer's full palette (spec §5): all avatar colors, darks and
// lights, plus the app's own charcoal and warm white. Deduped — some
// foregrounds repeat background hues. Computed once.
final notePalette = () {
  final colors = <Color>[charcoal, warmWhite];
  for (final pair in avatarColorMap.values) {
    colors.add(pair.$1);
  }
  for (final pair in avatarColorMap.values) {
    colors.add(pair.$2);
  }
  final seen = <int>{};
  return List<Color>.unmodifiable(
    [
      for (final color in colors)
        if (seen.add(color.toARGB32())) color,
    ],
  );
}();
