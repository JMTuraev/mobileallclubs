# Project tools

## `bump_version.dart`

Bumps the `version:` line in `pubspec.yaml`. Keeps Play Store / App Store
`versionCode` monotonically increasing so subsequent uploads are accepted.

```bash
dart run tool/bump_version.dart            # 1.0.1+10002 -> 1.0.1+10003
dart run tool/bump_version.dart --patch    # 1.0.1+10002 -> 1.0.2+10003
dart run tool/bump_version.dart --minor    # 1.0.2+10003 -> 1.1.0+10004
dart run tool/bump_version.dart --set 2.0.0+20000
```

Run before every release build:

```bash
dart run tool/bump_version.dart --patch
flutter build appbundle --release
```

In CI, bump on tagged release jobs only — local commits should not bump the
build counter (creates noisy diffs).
