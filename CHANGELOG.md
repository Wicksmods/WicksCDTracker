# Wick's CD Tracker — Changelog

## 0.3.1 — 2026-04-25

### Title bar harmonization

Header now matches the canonical Wick suite spec — taller (32px), two-tone title (`Wick's` in fel-green, `CD Tracker` in cream, FRIZQT 14 outlined), bordered ✕ close button, fel-green underline at the bottom of the header, drag-by-header. The settings cog moved into the header right side, immediately to the left of the close button.

No functional changes.

## 0.3.0 — 2026-04-22

### Close button, auto-sized backdrop, no more manual resize

- **× close button** at the far top-right of the header (matches Wick's Trade Hall and Wick's TBC BIS Tracker). Settings cog now sits immediately to the left of the close button.
- **Backdrop auto-sizes to the roster.** The frame now re-sizes itself on every refresh so the dark panel always covers every player row. Previously, rows rendered outside the backdrop when a full party was tracked and the frame hadn't been manually resized tall enough.
- **Resize grip removed.** Since the frame sizes itself to the data, the BOTTOMRIGHT resize grip no longer earned its keep. The fel-green L-bracket at that corner remains as a decorative element. Saved `WCDTSettings.size` from older versions is safely ignored.

## 0.2.1 — 2026-04-21

### Brand identity pass

Normalized the five locked Wick brand palette tokens to hex-exact values. Part of a coordinated pass across the Wick addon suite (BIS Tracker, CD Tracker, Trade Hall).

**Visual impact:** imperceptible — shifts are <2 sRGB units per channel.

| Token          | Before                            | After                               |
|----------------|-----------------------------------|-------------------------------------|
| C_BG           | `0.05, 0.04, 0.08, 0.97`          | `0.051, 0.039, 0.078, 0.97`         |
| C_HEADER_BG    | `0.09, 0.07, 0.16, 1`             | `0.090, 0.067, 0.141, 1`            |
| C_BORDER       | `0.22, 0.18, 0.36, 1`             | `0.220, 0.188, 0.345, 1`            |
| C_GREEN        | `0.31, 0.78, 0.47, 1`             | `0.310, 0.780, 0.471, 1`            |
| C_TEXT_NORMAL  | `0.83, 0.78, 0.63, 1`             | `0.831, 0.784, 0.631, 1`            |

The brand style reference the header comment already pointed at now exists: `memory/reference_wick_brand_style.md`.
