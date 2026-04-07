import 'package:flutter/material.dart';

enum LockerEntryMode { manual, magnetic }

class StartSessionDialogResult {
  const StartSessionDialogResult({required this.mode, this.lockerNumber});

  final LockerEntryMode mode;
  final String? lockerNumber;
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
  LockerEntryMode _mode = LockerEntryMode.manual;

  @override
  void dispose() {
    _lockerController.dispose();
    super.dispose();
  }

  void _confirm() {
    final lockerValue = _lockerController.text.trim();
    if (_mode == LockerEntryMode.manual && lockerValue.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      StartSessionDialogResult(
        mode: _mode,
        lockerNumber: _mode == LockerEntryMode.manual ? lockerValue : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm =
        _mode == LockerEntryMode.magnetic ||
        _lockerController.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Give key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.clientName, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          SegmentedButton<LockerEntryMode>(
            segments: const [
              ButtonSegment(
                value: LockerEntryMode.manual,
                label: Text('Manual'),
                icon: Icon(Icons.pin_outlined),
              ),
              ButtonSegment(
                value: LockerEntryMode.magnetic,
                label: Text('Magnetic'),
                icon: Icon(Icons.nfc_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 16),
          if (_mode == LockerEntryMode.manual)
            TextField(
              controller: _lockerController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
              decoration: const InputDecoration(
                labelText: 'Locker number',
                hintText: 'Enter locker code',
              ),
            )
          else
            Text(
              'Use this mode when you are working without a manual locker code. The production backend accepts a null locker number in this path.',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canConfirm ? _confirm : null,
          child: const Text('Start session'),
        ),
      ],
    );
  }
}
