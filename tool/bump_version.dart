// Bumps the build number (after `+`) in pubspec.yaml.
//
// Usage:
//   dart run tool/bump_version.dart              # bumps build number by 1
//   dart run tool/bump_version.dart --minor      # bumps minor, resets patch
//   dart run tool/bump_version.dart --patch      # bumps patch
//   dart run tool/bump_version.dart --set 1.2.0+10200
//
// The build number convention: MMmmpp where MM=major, mm=minor, pp=patch
// counter — keeps Play Store versionCode monotonically increasing.

import 'dart:io';

void main(List<String> args) {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found in current directory.');
    exit(2);
  }

  final lines = pubspec.readAsLinesSync();
  final versionIndex = lines.indexWhere((l) => l.startsWith('version:'));
  if (versionIndex < 0) {
    stderr.writeln('No "version:" line found in pubspec.yaml.');
    exit(2);
  }

  final current = lines[versionIndex].substring('version:'.length).trim();
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$').firstMatch(current);
  if (match == null) {
    stderr.writeln('Cannot parse version: "$current". Expected X.Y.Z+N.');
    exit(2);
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  var build = int.parse(match.group(4)!);

  String next;
  if (args.contains('--set')) {
    final idx = args.indexOf('--set');
    if (idx + 1 >= args.length) {
      stderr.writeln('--set requires a value (e.g. --set 1.2.0+10200)');
      exit(2);
    }
    next = args[idx + 1];
  } else if (args.contains('--minor')) {
    minor += 1;
    patch = 0;
    build += 1;
    next = '$major.$minor.$patch+$build';
  } else if (args.contains('--patch')) {
    patch += 1;
    build += 1;
    next = '$major.$minor.$patch+$build';
  } else {
    build += 1;
    next = '$major.$minor.$patch+$build';
  }

  lines[versionIndex] = 'version: $next';
  pubspec.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('Bumped version: $current -> $next');
}
