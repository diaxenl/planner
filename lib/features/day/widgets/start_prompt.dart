import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Shown in place of the usual sections on a day with nothing of your
/// own on it: one question, one field. Submitting hands the raw text
/// (capture shorthand allowed) to [onSubmit], which adds it as an Outcome.
class StartPrompt extends StatefulWidget {
  const StartPrompt({
    super.key,
    required this.dayLabel,
    required this.onSubmit,
  });

  /// "today", "tomorrow", or e.g. "on Friday".
  final String dayLabel;
  final ValueChanged<String> onSubmit;

  @override
  State<StartPrompt> createState() => _StartPromptState();
}

class _StartPromptState extends State<StartPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty) return;
    _controller.clear();
    widget.onSubmit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "What's the one thing you need to get done ${widget.dayLabel}?",
            style: text.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'It goes straight onto your schedule. Add anything else below.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.go,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'e.g. "Finish the proposal 2h"',
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => FilledButton(
              onPressed: _controller.text.trim().isEmpty ? null : _submit,
              child: const Text('Plan it'),
            ),
          ),
        ],
      ),
    );
  }
}
