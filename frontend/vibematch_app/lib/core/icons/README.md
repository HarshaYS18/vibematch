# VibeMatch Icon Pack Layer

This folder contains the central icon mapping layer for the Flutter app.

## Current state

`vm_icons.dart` uses safe Flutter Material fallback icons so the app keeps compiling without new dependencies.

Feature screens should import icons from:

```dart
import 'package:vibematch_app/core/icons/vm_icons.dart';
```

Then use:

```dart
Icon(VMIcons.home)
Icon(VMIcons.gift)
Icon(VMIcons.wallet)
```

For project-specific asset icons, place files under:

```text
assets/icons/
```

Example:

```dart
VMIcon(
  fallback: VMIcons.coin,
  assetName: 'gold_coin',
)
```

Expected asset paths:

```text
assets/icons/gold_coin.png
assets/icons/gold_coin.webp
```

## Later dependency upgrade

When editing `pubspec.yaml` locally, add:

```yaml
dependencies:
  phosphor_flutter: ^2.1.0
  flutter_svg: ^2.0.10
```

Then run:

```bash
flutter pub get
flutter analyze
```

After that, swap selected mappings inside `vm_icons.dart` only. Do not import icon packs directly inside feature screens.
