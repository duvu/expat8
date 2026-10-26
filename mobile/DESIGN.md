---
name: Expat8 Mobile
version: alpha
description: Shared mobile design tokens and game-scene direction for Expat8.
colors:
  brandIndigo: "#352ABF"
  brandIndigoStrong: "#241B97"
  brandIndigoSoft: "#EFEEFF"
  brandIndigoDeep: "#211B58"
  brandMint: "#12CBA9"
  brandTeal: "#0F8A72"
  brandAmber: "#B7791F"
  brandInk: "#172033"
  brandPaper: "#F4F6FB"
  brandPaperMuted: "#F8FAFC"
  brandDanger: "#C2414B"
  gameSkyStudy: "#101D35"
  gameSkyCity: "#151B3B"
  gameSkyHarbor: "#0D263B"
  gameSkyLibrary: "#191832"
  gameSkySummit: "#1B2042"
typography:
  display:
    fontFamily: Material
    fontSize: 28sp
    fontWeight: 700
    lineHeight: 1.2
  heading:
    fontFamily: Material
    fontSize: 20sp
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: Material
    fontSize: 16sp
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: Material
    fontSize: 14sp
    fontWeight: 600
    lineHeight: 1.3
spacing:
  1: 4dp
  2: 8dp
  3: 12dp
  4: 16dp
  5: 20dp
  6: 24dp
rounded:
  control: 12dp
  card: 20dp
  surface: 24dp
components:
  primaryButton:
    backgroundColor: "{colors.brandIndigo}"
    textColor: "#FFFFFF"
    padding: 16dp
    rounded: "{rounded.control}"
  studyCard:
    backgroundColor: "{colors.brandPaperMuted}"
    textColor: "{colors.brandInk}"
    padding: 16dp
    rounded: "{rounded.card}"
  gameChapter:
    backgroundColor: "{colors.brandIndigoSoft}"
    textColor: "{colors.brandIndigoStrong}"
    rounded: 999dp
---

## Overview

Expat8 is a calm study companion with clear progress and small repeatable
  wins. The refreshed layered-book icon uses a royal-indigo field, white pages,
  and a mint spark. Mobile screens use Material 3 surfaces and typography;
  game scenes can be more expressive while keeping those brand anchors.

## Colors

Use royal indigo for primary actions and current context, semantic teal for
progress and success, amber for earned attention, and danger red for errors.
Mint is reserved for the logo spark and decorative highlights. Light and dark
surfaces come from `AppTheme`; game chapter colors are atmospheric background
tokens and never replace semantic status colors.

## Typography

Use the platform Material sans family. Product and screen titles use weight
700; actions and section labels use 600; reading content uses 400–500. Scores,
timers, and counts use tabular numerals. Keep labels readable when text scales.

## Layout

Use 4dp increments, 16dp page insets, and 48dp minimum control heights. Keep
game actions reachable, safe areas clear, and the play field free of decorative
text. Constrain puzzle boards to a readable centered width on larger screens.

## Elevation & Depth

Prefer tonal Material surfaces and restrained tinted shadows. Game depth comes
from layered vector landscapes, not heavy card shadows or colored edge stripes.

## Shapes

Use 12dp control corners, 20dp cards, and 24dp major surfaces. Pills are for
compact state labels such as the current story chapter.

## Components

Use shared `AppTheme` components and semantic `AppColors`. Game surfaces use
`GameStoryChapter`, `GameStoryScenePainter`, and `GameAudio` as the single
chapter, illustration, and soundtrack sources. Keep controls legible above
backdrop art and pair color states with text or icons.

## Do's and Don'ts

- Do derive new scenes from the Atlas of Learning chapter map in `GAMESTORY.md`.
- Do preserve app light/dark behavior, visible focus, touch targets, and reduced
  motion support.
- Don't add unrelated primary colors, fonts, shadows, or one-off spacing scales.
- Don't use color alone to communicate level, correctness, or progress.
- Don't add persistent story text over the active play field.

## Motion

Chapter changes happen at a level boundary. Keep the transition short, preserve
input availability, and use the static scene when reduced motion is enabled.
