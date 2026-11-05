import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Composer-style capture field pinned to the bottom of the Day screen.
/// Submitting hands the raw text to [onSubmit] and clears the field.
/// When [onSomethingCameUp] is set (today only), a bolt button opens the
/// interruption flow.
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
      child: Row(
        children: [
          if (widget.onSomethingCameUp != null)
            IconButton(
              tooltip: 'Something came up',
              onPressed: widget.onSomethingCameUp,
              icon: Icon(Icons.bolt, color: colors.accent),
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
                hintText: 'Add… e.g. "Prep board deck 1h *"',
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
    );
  }
}
