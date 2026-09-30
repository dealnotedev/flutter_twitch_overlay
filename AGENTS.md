# Flutter UI conventions

- Use `Gap` from `package:gap/gap.dart` for empty horizontal or vertical spacing
  between children of `Row`, `Column`, or `Flex`. Prefer `const Gap(...)` when
  the spacing is constant. Do not introduce spacer-only `SizedBox(width: ...)`
  or `SizedBox(height: ...)` in these layouts.
- Keep `SizedBox` when it constrains a child widget's dimensions, deliberately
  reserves an area in both dimensions, or uses `SizedBox.shrink()` /
  `SizedBox.expand()` for layout or an empty placeholder. Do not replace these
  with `Gap` mechanically.
- Apply this convention throughout the main app and `apps/music_controller`,
  including future UI changes.
