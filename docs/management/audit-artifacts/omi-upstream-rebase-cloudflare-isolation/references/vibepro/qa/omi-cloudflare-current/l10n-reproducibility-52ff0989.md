# l10n reproducibility (current HEAD)

- HEAD: `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- Flutter: `3.41.9` (Dart `3.11.5`)
- Generated Dart files: `50`
- Byte differences against HEAD after the generation invoked by the visual producer: `0`
- Untranslated upstream-derived warnings: `47 locales x 4 warnings = 188`; this is not zero.

The Flutter 3.41.9 web build that prepared this local producer emitted the 4 untranslated-message warnings for each of the 47 non-English generated locales. The subsequent golden producer retained the generated output without a byte change. The prior `7b2614c` note claiming zero warnings is retired.
