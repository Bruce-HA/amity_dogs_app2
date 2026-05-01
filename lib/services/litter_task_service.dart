import 'package:supabase_flutter/supabase_flutter.dart';

class LitterTaskService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> generateTasksForLitter({
    required String flowId,
    required String litterId,
    required DateTime dob,
    required DateTime expectedDueDate,
    required Map<String, dynamic> settings,
  }) async {
    final tasks = <Map<String, dynamic>>[];

    // ==============================
    // PRE-WHELPING ALWAYS TASKS
    // ==============================

    tasks.add(_task(
      flowId: flowId,
      group: 'Pre-Whelping',
      title: 'ALA breeding notification',
      type: 'ala_breeding_notification',
      dueDate: expectedDueDate.subtract(const Duration(days: 7)),
    ));

    // ==============================
    // POST-BIRTH ALWAYS TASKS
    // ==============================

    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Book Week 6 Vet Check',
      type: 'vet_booking',
      dueDate: dob.add(const Duration(days: 10)),
    ));

    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Order Puppy Food',
      type: 'food_order',
      dueDate: dob.add(const Duration(days: 28)),
    ));

    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Prepare SpaySecure',
      type: 'spaysecure',
      dueDate: dob.add(const Duration(days: 35)),
    ));

    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Prepare Knose Insurance',
      type: 'knose_insurance',
      dueDate: dob.add(const Duration(days: 35)),
    ));

    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Prepare LRF',
      type: 'lrf_preparation',
      dueDate: dob.add(const Duration(days: 49)),
    ));

    // ==============================
    // OPTIONAL: DRONTAL
    // ==============================

    if (settings['use_drontal'] == true) {
    for (final day in [14, 28, 42, 56]) {
      final week = (day / 7).round();

      tasks.add(_task(
        flowId: flowId,
        group: 'Puppy Care',
        title: 'Drontal Week $week',
        type: 'drontal',
        dueDate: dob.add(Duration(days: day)),
      ));
    }
  }

    // ==============================
    // OPTIONAL: BAYCOX
    // ==============================

    if (settings['use_baycox'] == true) {
    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Baycox — Mother',
      type: 'baycox',
      dueDate: dob.add(const Duration(days: 1)),
    ));

    for (final day in [21, 28]) {
      final week = (day / 7).round();

      tasks.add(_task(
        flowId: flowId,
        group: 'Puppy Care',
        title: 'Baycox Week $week — Mother + Puppies',
        type: 'baycox',
        dueDate: dob.add(Duration(days: day)),
      ));
    }
  }

  // ==============================
  // OPTIONAL: NAIL TRIMMING
  // ==============================

  if (settings['use_nail_trimming'] == true) {
    for (final day in [7, 14, 21, 28, 35, 42, 49, 56]) {
      final week = (day / 7).round();

      tasks.add(_task(
        flowId: flowId,
        group: 'Puppy Care',
        title: 'Trim Nails Week $week',
        type: 'nail_trimming',
        dueDate: dob.add(Duration(days: day)),
      ));
    }
  }

    // ==============================
    // OPTIONAL: ENS
    // ==============================

    if (settings['use_ens'] == true) {
      for (int day = 3; day <= 16; day++) {
        tasks.add(_task(
          flowId: flowId,
          group: 'Puppy Care',
          title: 'ENS Day $day',
          type: 'ens',
          dueDate: dob.add(Duration(days: day)),
        ));
      }
    }

    // ==============================
    // OPTIONAL: PHOTO REMINDERS
    // ==============================

    if (settings['use_photo_reminders'] == true) {
      for (final day in [7, 14, 21, 28, 35, 42, 49, 56]) {
        final week = (day / 7).round();
        tasks.add(_task(
          flowId: flowId,
          group: 'Puppy Care',
          title: 'Puppy Photos Day $day',
          type: 'photo_reminder',
          dueDate: dob.add(Duration(days: day)),
        ));
      }
    }

    for (final day in [28, 42, 56]) {
    final week = (day / 7).round();

    tasks.add(_task(
      flowId: flowId,
      group: 'Puppy Care',
      title: 'Pups $week weeks old',
      type: 'pups_milestone',
      dueDate: dob.add(Duration(days: day)),
    ));
  }

    tasks.add(_task(
    flowId: flowId,
    group: 'Puppy Care',
    title: 'SpaySecure Contract Check',
    type: 'spay_contract_check',
    dueDate: dob.add(const Duration(days: 52)),
  ));

    for (final task in tasks) {
      await _insertIfMissing(task);
    }
  }

  Map<String, dynamic> _task({
    required String flowId,
    required String group,
    required String title,
    required String type,
    required DateTime dueDate,
  }) {
    return {
      'flow_id': flowId,
      'task_group': group,
      'task_title': title,
      'task_type': type,
      'due_date': _dateOnly(dueDate),
      'completed': false,
      'task_source': 'system_generated',
    };
  }

  Future<void> _insertIfMissing(Map<String, dynamic> task) async {
    final existing = await _supabase
        .from('flow_tasks')
        .select('id')
        .eq('flow_id', task['flow_id'])
        .eq('task_type', task['task_type'])
        .eq('due_date', task['due_date'])
        .eq('task_source', 'system_generated')
        .maybeSingle();

    if (existing != null) return;

    await _supabase.from('flow_tasks').insert(task);
  }

  String _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')
        .first;
  }
}