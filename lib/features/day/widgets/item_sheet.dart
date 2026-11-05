import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/task.dart';
import '../../../state/day_planner_model.dart';

/// Bottom sheet to create, confirm, or edit an item.
///
/// Saves through [DayPlannerModel] directly so validation errors from the
/// model (overlap, outcome cap) show inline instead of closing the sheet.
/// Pops `true` when something was saved or deleted.
///
/// For an existing, unfinished item it also offers Start / Done / Cancel /
/// Move to tomorrow, gated by status; the sheet closes and [onAction]
/// performs it (so the caller can offer Undo).
class ItemSheet extends StatefulWidget {
  const ItemSheet({
    super.key,
    required this.model,
    this.existing,
    this.draft,
    this.onDeleted,
    this.onAction,
  });

  final DayPlannerModel model;

  /// The task being edited, or `null` to create.
  final Task? existing;

  /// Pre-filled fields for a new task (e.g. from capture). Ignored when
  /// [existing] is set.
  final Task? draft;

  /// Called after a delete so the caller can offer undo.
  final ValueChanged<Task>? onDeleted;

  /// Performs a status action on [existing] after the sheet closes.
  final void Function(ItemAction action, Task task)? onAction;

  static Future<bool?> show(
    BuildContext context, {
    required DayPlannerModel model,
    Task? existing,
    Task? draft,
    ValueChanged<Task>? onDeleted,
    void Function(ItemAction action, Task task)? onAction,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ItemSheet(
        model: model,
        existing: existing,
        draft: draft,
        onDeleted: onDeleted,
        onAction: onAction,
      ),
    );
  }

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

/// Status actions offered on an existing item.
enum ItemAction { start, done, cancel, tomorrow }

class _ItemSheetState extends State<ItemSheet> {
  static const _durationPresets = [15, 30, 45, 60, 90, 120];

  late final TextEditingController _title;
  late int _duration;
  late TaskType _type;
  TimeOfDay? _startTime;
  late bool _isOutcome;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing ?? widget.draft;
    _title = TextEditingController(text: t?.title ?? '');
    _duration = t?.durationMinutes ?? 30;
    _type = t?.type ?? TaskType.floating;
    _startTime = t?.startTime;
    _isOutcome = t?.isOutcome ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final needsTime = _type != TaskType.floating;
    final existing = widget.existing;

    if (existing != null && widget.model.isImported(existing)) {
      return _importedView(context, existing);
    }

    final atCap =
        !_isOutcome &&
        !(existing?.isOutcome ?? false) &&
        widget.model.tasks
                .where(
                  (t) =>
                      t.id != existing?.id &&
                      t.isOutcome &&
                      t.status != TaskStatus.cancelled,
                )
                .length >=
            widget.model.outcomeCap;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing?.title ?? 'New item',
              style: text.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (existing != null) _actions(context, existing),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEdit && (widget.draft?.title.isEmpty ?? true),
              maxLength: AppConstants.titleMaxLength,
              textCapitalization: TextCapitalization.sentences,
              style: text.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'What is it?',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            _label(context, 'HOW LONG'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _durationPresets)
                  _Choice(
                    label: AppUtils.formatDuration(m),
                    selected: _duration == m,
                    onTap: () => setState(() => _duration = m),
                  ),
                if (!_durationPresets.contains(_duration))
                  _Choice(
                    label: AppUtils.formatDuration(_duration),
                    selected: true,
                    onTap: () {},
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label(context, 'WHEN'),
            SegmentedButton<TaskType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TaskType.floating, label: Text('Anytime')),
                ButtonSegment(value: TaskType.pinned, label: Text('Set time')),
                ButtonSegment(value: TaskType.hard, label: Text('Meeting')),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() {
                  _type = s.first;
                  if (_type == TaskType.floating) _startTime = null;
                });
                if (_type != TaskType.floating && _startTime == null) {
                  _pickTime();
                }
              },
            ),
            const SizedBox(height: 6),
            Text(switch (_type) {
              TaskType.floating => 'HyperDay finds the best free slot.',
              TaskType.pinned =>
                'You pick the time. Nothing else can be booked over it.',
              TaskType.hard =>
                'A fixed commitment. Never moved, nothing booked over it.',
            }, style: text.bodyMedium),
            if (needsTime) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _pickTime,
                child: Text(
                  _startTime == null
                      ? 'Pick a start time'
                      : 'Starts ${AppUtils.formatClock(_startTime!.hour * 60 + _startTime!.minute)}',
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Outcome', style: text.bodyLarge),
              subtitle: Text(
                atCap
                    ? "You're at your limit of ${widget.model.outcomeCap}. "
                          'Change it in Settings.'
                    : 'One of the few things that make the day a win',
                style: text.bodyMedium,
              ),
              value: _isOutcome,
              onChanged: atCap ? null : (v) => setState(() => _isOutcome = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: colors.accent),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Save' : 'Add'),
            ),
            if (_isEdit)
              TextButton(onPressed: _delete, child: const Text('Delete')),
          ],
        ),
      ),
    );
  }

  /// Start / Done / Cancel / Tomorrow, as allowed by the item's status.
  Widget _actions(BuildContext context, Task task) {
    final notStarted = task.status == TaskStatus.notStarted;
    final inProgress = task.status == TaskStatus.inProgress;
    if (!notStarted && !inProgress) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          task.status == TaskStatus.complete ? 'Done' : 'Cancelled',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final isMeeting = task.type == TaskType.hard;

    Widget action(String label, ItemAction a) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: () {
        Navigator.of(context).pop(true);
        widget.onAction?.call(a, task);
      },
      child: Text(label),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (notStarted && !isMeeting) action('Start', ItemAction.start),
          if (!isMeeting) action('Done', ItemAction.done),
          action('Cancel', ItemAction.cancel),
          if (notStarted) action('Tomorrow', ItemAction.tomorrow),
        ],
      ),
    );
  }

  Widget _importedView(BuildContext context, Task task) {
    final text = Theme.of(context).textTheme;
    final start = task.startTime!.hour * 60 + task.startTime!.minute;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(task.title, style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${AppUtils.formatClock(start)}–'
            '${AppUtils.formatClock(start + task.durationMinutes)}',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'From your calendar. Edit it in your calendar app.',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _startTime ?? TimeOfDay(hour: (now.hour + 1).clamp(0, 23), minute: 0),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _startTime = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give it a name.');
      return;
    }
    if (_type != TaskType.floating && _startTime == null) {
      setState(() => _error = 'Pick a start time.');
      return;
    }
    if (_duration < AppConstants.durationMinMinutes ||
        _duration > AppConstants.durationMaxMinutes) {
      setState(() => _error = 'Duration must be 5 minutes to 8 hours.');
      return;
    }

    final model = widget.model;
    try {
      if (_isEdit) {
        model.updateTask(
          widget.existing!.id,
          widget.existing!.copyWith(
            title: title,
            durationMinutes: _duration,
            type: _type,
            startTime: () => _startTime,
            isOutcome: _isOutcome,
          ),
        );
      } else {
        final base = widget.draft;
        model.addTask(
          Task(
            title: title,
            durationMinutes: _duration,
            type: _type,
            startTime: _startTime,
            isOutcome: _isOutcome,
            isInterruption: base?.isInterruption ?? false,
            date: model.viewedDate,
          ),
        );
      }
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _delete() {
    final task = widget.existing!;
    widget.model.removeTask(task.id);
    widget.onDeleted?.call(task);
    Navigator.of(context).pop(true);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.textPrimary : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.textPrimary : colors.hairline,
          ),
        ),
        child: Text(
          label,
          style: text.bodySmall?.copyWith(
            color: selected ? colors.background : colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
