import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Composer-style capture field pinned to the bottom of the Day screen.
/// Submitting hands the raw text to [onSubmit] and clears the field.
/// When [onSomethingCameUp] is set (today only), a "Came up" button opens
/// the interruption flow. While the field is focused, shorthand chips sit
/// above it; tapping one appends its token, so the shorthand never has
/// to be learned up front.
class CaptureBar extends StatefulWidget {
  const CaptureBar({super.key, required this.onSubmit, this.onSomethingCameUp});

  final ValueChanged<String> onSubmit;
  final VoidCallback? onSomethingCameUp;

  @override
  State<CaptureBar> createState() => _CaptureBarState();
}

class _CaptureBarState extends State<CaptureBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// (label, token appended to the text) — tokens the capture parser
  /// reads; [_pickTime] opens a time picker.
  static const _shorthand = [
    ('★ Outcome', '*'),
    ('30m', '30m'),
    ('1h', '1h'),
    ('at …', _pickTime),
    ('tomorrow', 'tomorrow'),
    ('! High', '!'),
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  /// Stands in for a token: the chip opens a time picker instead.
  static const _pickTime = '';

  /// Asks for a time (starting at the next half hour) and appends it as
  /// "at 3pm" / "at 3:30pm", which the capture parser reads.
  Future<void> _appendPickedTime() async {
    final now = TimeOfDay.now();
    final next = (now.hour * 60 + now.minute) ~/ 30 * 30 + 30;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: next ~/ 60 % 24, minute: next % 60),
      helpText: 'At what time?',
    );
    if (!mounted) return;
    if (picked == null) {
      _focus.requestFocus();
      return;
    }
    final h12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
    final ampm = picked.period == DayPeriod.am ? 'am' : 'pm';
    final mm = picked.minute == 0
        ? ''
        : ':${picked.minute.toString().padLeft(2, '0')}';
    _append('at $h12$mm$ampm');
  }

  /// Appends [token] after a space and keeps typing at the end.
  void _append(String token) {
    final current = _controller.text.trimRight();
    final next = current.isEmpty ? token : '$current $token';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Keeps the keyboard up so several things can be captured in a row.
  void _submit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    widget.onSubmit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_focus.hasFocus)
            // A tap here counts as inside the field, so it stays focused.
            TextFieldTapRegion(
              child: SizedBox(
                height: 40,
                child: ListView(
                  key: const ValueKey('capture-shorthand'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    for (final (label, token) in _shorthand)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(label),
                          labelStyle: Theme.of(context).textTheme.bodySmall,
                          backgroundColor: colors.surface,
                          side: BorderSide(color: colors.hairline),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => token == _pickTime
                              ? _appendPickedTime()
                              : _append(token),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              if (widget.onSomethingCameUp != null)
                // Labelled: an icon alone didn't say what it does.
                Tooltip(
                  message: 'Something came up',
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: widget.onSomethingCameUp,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Came up'),
                  ),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Add… e.g. "Call Sam 20m at 3"',
                    fillColor: colors.surface,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add',
                onPressed: _submit,
                icon: Icon(Icons.arrow_upward, color: colors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
