import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/task.dart';

/// Bottom sheet for adding or editing a task.
///
/// When [existingTask] is `null`, the sheet is in "add" mode.
/// When [existingTask] is provided, the sheet is in "edit" mode and
/// fields are pre-populated.
///
/// Returns the created/updated [Task] via [Navigator.pop] on submit,
/// or `null` if the user dismisses the sheet.
class TaskBottomSheet extends StatefulWidget {
  const TaskBottomSheet({
    super.key,
    required this.date,
    this.existingTask,
  });

  /// The calendar date to assign the task to.
  final DateTime date;

  /// If non-null, the sheet pre-populates fields for editing.
  final Task? existingTask;

  /// Shows the bottom sheet and returns the resulting [Task], or `null`.
  static Future<Task?> show(
    BuildContext context, {
    required DateTime date,
    Task? existingTask,
  }) {
    return showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TaskBottomSheet(date: date, existingTask: existingTask),
    );
  }

  @override
  State<TaskBottomSheet> createState() => _TaskBottomSheetState();
}

class _TaskBottomSheetState extends State<TaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late TaskType _type;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late Priority _priority;

  bool get _isEditing => widget.existingTask != null;
  bool get _isTimedType => _type != TaskType.floating;

  /// Computes duration in minutes from start and end times.
  /// Returns `null` if either time is unset or end is not after start.
  int? get _computedDuration {
    if (_startTime == null || _endTime == null) return null;
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    final diff = endMin - startMin;
    return diff > 0 ? diff : null;
  }

  String get _typeHint {
    switch (_type) {
      case TaskType.floating:
        return 'We\'ll find the best time slot for you';
      case TaskType.pinned:
        return 'Set a time — we may suggest adjustments';
      case TaskType.hard:
        return 'Fixed time — won\'t be moved';
    }
  }

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _titleController = TextEditingController(text: t?.title ?? '');
    _durationController = TextEditingController(
      text: t != null ? t.durationMinutes.toString() : '',
    );
    _type = t?.type ?? TaskType.floating;
    _startTime = t?.startTime;
    if (t != null && t.startTime != null) {
      final endMin =
          t.startTime!.hour * 60 + t.startTime!.minute + t.durationMinutes;
      _endTime = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);
    } else {
      _endTime = null;
    }
    _priority = t?.priority ?? Priority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.paddingLarge,
        right: AppConstants.paddingLarge,
        top: AppConstants.paddingLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            AppConstants.paddingLarge,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle bar ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.only(bottom: AppConstants.paddingLarge),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title ──
              Text(
                _isEditing ? 'Edit Task' : 'New Task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.paddingLarge),

              // 1. Title field
              TextFormField(
                controller: _titleController,
                maxLength: AppConstants.titleMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What do you need to do?',
                  border: OutlineInputBorder(),
                ),
                validator: _validateTitle,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // 2. Scheduling type
              Text(
                'Scheduling',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              SegmentedButton<TaskType>(
                segments: const [
                  ButtonSegment(
                    value: TaskType.floating,
                    label: Text('Flexible'),
                    icon: Icon(Icons.auto_fix_high, size: 18),
                  ),
                  ButtonSegment(
                    value: TaskType.pinned,
                    label: Text('Timed'),
                    icon: Icon(Icons.schedule, size: 18),
                  ),
                  ButtonSegment(
                    value: TaskType.hard,
                    label: Text('Locked'),
                    icon: Icon(Icons.lock_outline, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selected) {
                  setState(() {
                    _type = selected.first;
                    if (_type == TaskType.floating) {
                      _startTime = null;
                      _endTime = null;
                    }
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: AppConstants.paddingSmall,
                  left: AppConstants.paddingSmall,
                ),
                child: Text(
                  _typeHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),

              // 3. Duration field (flexible only)
              if (!_isTimedType) ...[
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: '5–480',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateDuration,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: AppConstants.paddingLarge),
              ],

              // 4. Start / End time pickers (timed & locked only)
              if (_isTimedType) ...[
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerButton(
                        label: 'Start',
                        time: _startTime,
                        onChanged: (t) => setState(() => _startTime = t),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingSmall,
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: _TimePickerButton(
                        label: 'End',
                        time: _endTime,
                        onChanged: (t) => setState(() => _endTime = t),
                      ),
                    ),
                  ],
                ),
                if (_computedDuration != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppConstants.paddingSmall,
                      left: AppConstants.paddingSmall,
                    ),
                    child: Text(
                      'Duration: $_computedDuration min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                const SizedBox(height: AppConstants.paddingLarge),
              ],

              // 5. Priority selector
              Text('Priority', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppConstants.paddingSmall),
              SegmentedButton<Priority>(
                segments: const [
                  ButtonSegment(value: Priority.low, label: Text('Low')),
                  ButtonSegment(value: Priority.medium, label: Text('Medium')),
                  ButtonSegment(value: Priority.high, label: Text('High')),
                ],
                selected: {_priority},
                onSelectionChanged: (selected) {
                  setState(() => _priority = selected.first);
                },
              ),
              const SizedBox(height: AppConstants.paddingXLarge),

              // ── Submit button ──
              FilledButton(
                onPressed: _onSubmit,
                child: Text(_isEditing ? 'Save Changes' : 'Add Task'),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
            ],
          ),
        ),
      ),
    );
  }

  // ── Validation ──────────────────────────────────────────────────────

  String? _validateTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Title is required';
    if (trimmed.length > AppConstants.titleMaxLength) {
      return 'Max ${AppConstants.titleMaxLength} characters';
    }
    return null;
  }

  String? _validateDuration(String? value) {
    if (value == null || value.trim().isEmpty) return 'Duration is required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a whole number';
    if (parsed < AppConstants.durationMinMinutes) {
      return 'Minimum ${AppConstants.durationMinMinutes} minutes';
    }
    if (parsed > AppConstants.durationMaxMinutes) {
      return 'Maximum ${AppConstants.durationMaxMinutes} minutes';
    }
    return null;
  }

  // ── Submit ──────────────────────────────────────────────────────────

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    int duration;

    if (_isTimedType) {
      // Validate start / end for timed & locked tasks.
      if (_startTime == null) {
        _showSnack('Please select a start time');
        return;
      }
      if (_endTime == null) {
        _showSnack('Please select an end time');
        return;
      }
      final computed = _computedDuration;
      if (computed == null || computed <= 0) {
        _showSnack('End time must be after start time');
        return;
      }
      if (computed < AppConstants.durationMinMinutes) {
        _showSnack(
          'Minimum duration is ${AppConstants.durationMinMinutes} minutes',
        );
        return;
      }
      if (computed > AppConstants.durationMaxMinutes) {
        _showSnack(
          'Maximum duration is ${AppConstants.durationMaxMinutes} minutes',
        );
        return;
      }
      duration = computed;
    } else {
      duration = int.parse(_durationController.text.trim());
    }

    final task = widget.existingTask != null
        ? widget.existingTask!.copyWith(
            title: title,
            durationMinutes: duration,
            type: _type,
            startTime: () => _startTime,
            priority: _priority,
          )
        : Task(
            title: title,
            durationMinutes: duration,
            type: _type,
            startTime: _startTime,
            priority: _priority,
            date: widget.date,
          );

    Navigator.of(context).pop(task);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Time Picker
// ─────────────────────────────────────────────────────────────────────────────

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = time != null ? time!.format(context) : label;

    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      icon: const Icon(Icons.access_time, size: 18),
      label: Text(display),
    );
  }
}
