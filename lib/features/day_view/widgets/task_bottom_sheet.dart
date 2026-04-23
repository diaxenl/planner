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
  late Priority _priority;

  bool get _isEditing => widget.existingTask != null;

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

              // 2. Duration field
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

              // 3. Task type toggle
              Text('Type', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppConstants.paddingSmall),
              SegmentedButton<TaskType>(
                segments: const [
                  ButtonSegment(
                    value: TaskType.floating,
                    label: Text('Floating'),
                    icon: Icon(Icons.swap_vert, size: 18),
                  ),
                  ButtonSegment(
                    value: TaskType.pinned,
                    label: Text('Pinned'),
                    icon: Icon(Icons.push_pin_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: TaskType.hard,
                    label: Text('Hard'),
                    icon: Icon(Icons.lock_outline, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selected) {
                  setState(() {
                    _type = selected.first;
                    // Clear start time when switching to floating.
                    if (_type == TaskType.floating) {
                      _startTime = null;
                    }
                  });
                },
              ),
              const SizedBox(height: AppConstants.paddingLarge),

              // 4. Start time picker (only for pinned / hard)
              if (_type != TaskType.floating) ...[
                _StartTimePicker(
                  startTime: _startTime,
                  onChanged: (t) => setState(() => _startTime = t),
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

    // Extra check: pinned/hard must have a start time selected.
    if (_type != TaskType.floating && _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final duration = int.parse(_durationController.text.trim());

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
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Time Picker
// ─────────────────────────────────────────────────────────────────────────────

class _StartTimePicker extends StatelessWidget {
  const _StartTimePicker({required this.startTime, required this.onChanged});

  final TimeOfDay? startTime;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = startTime != null
        ? startTime!.format(context)
        : 'Select start time';

    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      icon: const Icon(Icons.access_time, size: 18),
      label: Text(label),
    );
  }
}
