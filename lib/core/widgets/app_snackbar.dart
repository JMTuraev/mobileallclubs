import 'package:flutter/material.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
OverlayEntry? _activeOverlayEntry;

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  final normalizedMessage = message.trim();
  if (normalizedMessage.isEmpty) {
    return;
  }

  void dispatch() {
    final overlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) {
      _activeOverlayEntry?.remove();
      final entry = OverlayEntry(
        builder: (overlayContext) =>
            _AppSnackBarOverlay(message: normalizedMessage),
      );
      _activeOverlayEntry = entry;
      overlay.insert(entry);
      Future<void>.delayed(duration, () {
        if (_activeOverlayEntry == entry) {
          _activeOverlayEntry = null;
        }
        entry.remove();
      });
      return;
    }

    final messenger =
        appScaffoldMessengerKey.currentState ??
        (context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(normalizedMessage), duration: duration),
      );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => dispatch());
}

class _AppSnackBarOverlay extends StatelessWidget {
  const _AppSnackBarOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final bottomInset = mediaQuery?.viewInsets.bottom ?? 0;
    final safeBottom = mediaQuery?.padding.bottom ?? 0;
    final bottomOffset = bottomInset > 0
        ? bottomInset + 24
        : safeBottom + 104;

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomOffset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xEE243142),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x55FFFFFF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x50000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
