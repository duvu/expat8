# Expat8 brand system

## Brand idea

Expat8 turns small, repeatable study sessions into visible discovery. The new
signature is an open, layered book with a mint spark rising from its center:
learning opens possibilities, and each useful insight adds momentum. The
product should feel clear and capable, with a little energy at moments of
progress.

## Name and voice

- Product name: **Expat8**
- Descriptor: **Learn a little. Use it everywhere.**
- Voice: clear, encouraging, specific, and quietly confident.
- Prefer: “Review 12 words”, “Ready for another round?”, “3 words due today”.
- Avoid hype, guilt, vague promises, and excessive exclamation marks.
- Sentence case is the default across mobile and web.

## Signature mark

The refreshed mark uses layered open pages and a centered four-point mint spark.
Use the square indigo-gradient icon on app tiles and compact brand placements.
Use the SVG lockup when the product name and descriptor need to appear together.
At small sizes, use the monochrome mark so the page silhouette stays clear.

The page symbol stays white; the spark stays mint. Gradients belong to the
icon field and expressive campaign artwork, never inside the symbol itself.
Keep clear space around the mark equal to at least one quarter of its width.
Do not redraw, stretch, rotate, shadow, or place copy inside the mark.

## Shared color tokens

| Token | Value | Meaning |
| --- | --- | --- |
| `brand.indigo` / `--color-accent` | `#352ABF` | Primary action, navigation, focus |
| `brand.indigoStrong` / `--color-accent-strong` | `#241B97` | Active text and hover |
| `brand.indigoSoft` / `--color-accent-soft` | `#EFEEFF` | Selected and learning-focus surfaces |
| `brand.indigoDeep` | `#211B58` | Dark display text and wordmark ink |
| `brand.mint` | `#12CBA9` | The spark in the mark and decorative highlights |
| `brand.teal` / `--color-progress` | `#0F8A72` | Progress, mastered, completed |
| `brand.amber` / `--color-attention` | `#B7791F` | Due soon and attention |
| `brand.ink` / `--color-ink` | `#172033` | Primary text and dark surfaces |
| `brand.paper` / `--color-canvas` | `#F4F6FB` | Main light canvas |
| `brand.paperMuted` / `--color-surface-muted` | `#F8FAFC` | Secondary surface |
| `brand.danger` / `--color-danger` | `#C2414B` | Errors and destructive actions |

The app icon uses a royal-indigo field that moves from `#2B25A9` through
`#3028B8` to `#1F1B9B`. Keep that gradient to brand artwork and icon surfaces.
Use the solid `brand.indigo` token for interface actions so white action text
retains accessible contrast. Use darker teal for readable progress labels;
mint is a mark accent, not small text.

Mobile and web share these anchors. Dark mode may derive brighter semantic
states, but must retain the royal-indigo and mint relationship.

## Type and iconography

- Use the platform-native sans-serif stack: Material typography on Flutter and
  the system sans stack on web.
- Use weight 700 for product titles, 600 for actions and section labels, and
  400–500 for reading content.
- Use tabular numerals for streaks, counts, scores, and analytics.
- Use Material Icons on Flutter and one rounded SVG icon family on web.
- Do not use emoji as interface icons.

## Surface language

- Product surfaces stay paper-like and calm; use indigo for the main action and
  mint only for the spark or restrained decorative accents.
- Light mode uses paper canvas, white or muted panels, and indigo tonal
  selection. Dark mode uses graphite surfaces and a brighter indigo action.
- Rounded geometry: compact controls 8–12px, cards 18–20px, main surfaces 24px.
- Depth is quiet: tonal shifts plus soft tinted shadows.
- Campaign and game artwork may use the full icon gradient and layered book
  imagery while preserving the same mark silhouette and mint spark.

## Product applications

### Mobile app

- Use the refreshed app icon on launcher, store, and PWA surfaces.
- Use indigo for primary study actions; use semantic teal for completed and
  mastered feedback.
- Pair progress with a label, count, or icon.
- Keep game scenes expressive but retain the shared book-and-spark identity.

### Web dashboard

- Use the square mark beside the Expat8 wordmark in navigation.
- Use the same indigo active state as mobile and the same teal, amber, and
  danger meanings for operational status.
- Keep page titles and navigation in sentence case and system typography.

## Do / don't

- Do use the current assets from `branding/` and `branding/release/`.
- Do preserve the icon's page layering, centered spark, and indigo field.
- Do pair status color with text or iconography.
- Don't introduce a competing primary accent or random gradients.
- Don't use mint for small text on light surfaces.
- Don't redraw the mark differently per screen.
- Don't use “Expat 8”, “EXPAT8”, or product-specific abbreviations in UI copy.
