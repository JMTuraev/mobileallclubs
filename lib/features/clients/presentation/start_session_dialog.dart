import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';

class StartSessionDialogResult {
  const StartSessionDialogResult({required this.lockerNumber});

  final String lockerNumber;
}

Future<StartSessionDialogResult?> showStartSessionDialog(
  BuildContext context, {
  required String clientName,
}) {
  return showDialog<StartSessionDialogResult>(
    context: context,
    builder: (context) => _StartSessionDialog(clientName: clientName),
  );
}

class _StartSessionDialog extends StatefulWidget {
  const _StartSessionDialog({required this.clientName});

  final String clientName;

  @override
  State<_StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<_StartSessionDialog> {
  final _lockerController = TextEditingController();

  @override
  void dispose() {
    _lockerController.dispose();
    super.dispose();
  }

  void _confirm() {
    final lockerValue = _lockerController.text.trim();
    if (lockerValue.isEmpty) {
      return;
    }

    Navigator.of(
      context,
    ).pop(StartSessionDialogResult(lockerNumber: lockerValue));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppLiquidGlass(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF0283A4D), Color(0xDE17212C)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.clientName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Give key',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.mutedInk,
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lockerController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirm(),
              decoration: const InputDecoration(
                labelText: 'Key number',
                hintText: 'Enter key number',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
