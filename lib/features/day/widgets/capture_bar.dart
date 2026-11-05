import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Composer-style capture field pinned to the bottom of the Day screen.
/// Submitting hands the raw text to [onSubmit] and clears the field.
class CaptureBar extends StatefulWidget {
  const CaptureBar({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<CaptureBar> createState() => _CaptureBarState();
}

class _CaptureBarState extends State<CaptureBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    _controller.clear();
    widget.onSubmit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Add something…',
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
