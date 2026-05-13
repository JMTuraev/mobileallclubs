import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class StartSessionDialogResult {
  const StartSessionDialogResult({required this.lockerNumber});

  final String lockerNumber;
}

Future<StartSessionDialogResult?> showStartSessionDialog(
  BuildContext context, {
  required String clientName,
}) {
  return showModalBottomSheet<StartSessionDialogResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
  static const int _maxLockerDigits = 4;

  final _lockerController = TextEditingController();
  final _lockerFocusNode = FocusNode();

  bool get _canConfirm => _lockerController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _lockerController.addListener(_handleValueChanged);
    _lockerFocusNode.addListener(_handleValueChanged);
  }

  @override
  void dispose() {
    _lockerController.removeListener(_handleValueChanged);
    _lockerFocusNode.removeListener(_handleValueChanged);
    _lockerController.dispose();
    _lockerFocusNode.dispose();
    super.dispose();
  }

  void _handleValueChanged() {
    if (mounted) {
      setState(() {});
    }
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

  int _visibleLockerCellsFor(String lockerValue) {
    final length = lockerValue.length;
    if (length >= _maxLockerDigits) {
      return _maxLockerDigits;
    }

    return length + 1;
  }

  Widget _buildLockerCell({
    required ThemeData theme,
    required String character,
    required bool isActive,
    required bool isFilled,
    required double cellSize,
    required double fontSize,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: cellSize,
      height: cellSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFFF1F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(cellSize * 0.28),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : isFilled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x173B82F6),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        character,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _buildHeaderIllustration(bool isCompactLayout) {
    if (isCompactLayout) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F9FF), Color(0xFFE3EEFF)],
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x143B82F6),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              child: Transform.rotate(
                angle: -0.16,
                child: Container(
                  width: 18,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE8FF),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.lock_open_rounded,
              size: 28,
              color: AppColors.primary,
            ),
            const Positioned(
              right: 22,
              bottom: 20,
              child: Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final lockerValue = _lockerController.text.trim();
    final visibleLockerCells = _visibleLockerCellsFor(lockerValue);
    final isCompactLayout = _lockerFocusNode.hasFocus || viewInsets.bottom > 0;
    final sheetPadding = isCompactLayout ? 14.0 : 18.0;
    final headerTitleSize = isCompactLayout ? 18.0 : 22.0;
    final sectionGap = isCompactLayout ? 10.0 : 16.0;
    final cellSize = isCompactLayout ? 50.0 : 58.0;
    final actionVerticalPadding = isCompactLayout ? 11.0 : 14.0;
    final inputShellPadding = isCompactLayout
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.fromLTRB(16, 14, 16, 14);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                sheetPadding,
                isCompactLayout ? 14 : 16,
                sheetPadding,
                isCompactLayout ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.9),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F16324F),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Color(0x123B82F6),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompactLayout ? 10 : 12),
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            Text(
                              'Shkaf kalitini biriktir',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: headerTitleSize,
                                height: 1.12,
                              ),
                            ),
                            SizedBox(height: isCompactLayout ? 8 : 10),
                            Text(
                              widget.clientName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.ink,
                                fontSize: isCompactLayout ? 15 : 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: isCompactLayout ? 4 : 6),
                            Text(
                              'Mijoz uchun shkaf raqamini kiriting',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.mutedInk,
                                fontSize: isCompactLayout ? 12 : 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.mutedInk,
                          splashRadius: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  if (!isCompactLayout) ...[
                    SizedBox(height: isCompactLayout ? 6 : 12),
                    _buildHeaderIllustration(isCompactLayout),
                  ],
                  SizedBox(height: sectionGap),
                  Text(
                    'Kalit raqami',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontSize: isCompactLayout ? 14 : 15.5,
                    ),
                  ),
                  SizedBox(height: isCompactLayout ? 6 : 10),
                  Container(
                    width: double.infinity,
                    padding: inputShellPadding,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFAFDFF), Color(0xFFF3F8FF)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _lockerFocusNode.hasFocus
                            ? AppColors.primary.withValues(alpha: 0.42)
                            : AppColors.border,
                        width: _lockerFocusNode.hasFocus ? 1.4 : 1,
                      ),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _lockerFocusNode.requestFocus(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: isCompactLayout ? 8 : 10,
                                runSpacing: 8,
                                children: List.generate(visibleLockerCells, (
                                  index,
                                ) {
                                  final character = index < lockerValue.length
                                      ? lockerValue[index]
                                      : '';
                                  final isFilled = character.isNotEmpty;
                                  final isLastCell =
                                      index == visibleLockerCells - 1;
                                  final isActive =
                                      _lockerFocusNode.hasFocus &&
                                      ((!isFilled && isLastCell) ||
                                          (lockerValue.length ==
                                                  _maxLockerDigits &&
                                              isLastCell));

                                  return _buildLockerCell(
                                    theme: theme,
                                    character: character,
                                    isActive: isActive,
                                    isFilled: isFilled,
                                    cellSize: cellSize,
                                    fontSize: isCompactLayout ? 20 : 24,
                                  );
                                }),
                              ),
                            ),
                          ),
                          SizedBox(height: isCompactLayout ? 6 : 10),
                          Text(
                            '1 dan 4 tagacha raqam kiriting',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.mutedInk,
                              fontSize: isCompactLayout ? 11 : 11.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    height: 1,
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _lockerController,
                        focusNode: _lockerFocusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _confirm(),
                        onEditingComplete: _confirm,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_maxLockerDigits),
                        ],
                        maxLength: _maxLockerDigits,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompactLayout ? 6 : 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canConfirm ? _confirm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: actionVerticalPadding,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
