import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Where an interruption goes.
enum InterruptionChoice { now, laterToday, tomorrow }

/// "Something came up": type it, then decide Now / Later today / Tomorrow.
/// Pops `(text, choice)` or `null` if dismissed.
class InterruptionSheet extends StatefulWidget {
  const InterruptionSheet({super.key});

  static Future<(String, InterruptionChoice)?> show(BuildContext context) =>
      showModalBottomSheet<(String, InterruptionChoice)>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const InterruptionSheet(),
      );

  @override
  State<InterruptionSheet> createState() => _InterruptionSheetState();
}

class _InterruptionSheetState extends State<InterruptionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choose(InterruptionChoice choice) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop((text, choice));
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: colors.accent, size: 20),
              const SizedBox(width: 6),
              Text('Something came up', style: text.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: text.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'What is it? e.g. "Fix prod outage 45m"',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _choose(InterruptionChoice.now),
            child: const Text('Do it now'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _choose(InterruptionChoice.laterToday),
                  child: const Text('Later today'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _choose(InterruptionChoice.tomorrow),
                  child: const Text('Tomorrow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
