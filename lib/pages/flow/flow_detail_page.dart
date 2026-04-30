import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../dog_details_page.dart';
import '../litters/litter_puppies_page.dart';
import '../litters/litter_weights_page.dart';
import '../../services/litter_task_service.dart';

class FlowDetailPage extends StatefulWidget {
  final String flowId;

  const FlowDetailPage({
    super.key,
    required this.flowId,
  });

  @override
  State<FlowDetailPage> createState() => _FlowDetailPageState();
}

class _FlowDetailPageState extends State<FlowDetailPage> {
 
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? currentLitter;
  Map<String, dynamic>? litterSettings;


  bool useDrontal = false;
  bool useBaycox = false;
  bool useNailTrimming = false;
  bool useEns = false;
  bool usePhotoReminders = false;

  bool savingLitterSettings = false;

  bool loading = true;

  final ScrollController _scrollController = ScrollController();

  final Map<String, GlobalKey> sectionKeys = {
    'Season': GlobalKey(),
    'Progesterone': GlobalKey(),
    'Ovulation': GlobalKey(),
    'Mating': GlobalKey(),
    'Pre-Whelping': GlobalKey(),
    'Litter Settings': GlobalKey(),
    'Whelping': GlobalKey(),
    'Puppy Care': GlobalKey(),
  };
  Map<String, dynamic>? flow;
  List<Map<String, dynamic>> tasks = [];

  static const Color flowBackground = Color(0xFFFFF8EA);
  static const Color flowHeader = Color(0xFFF3DFC1);

  @override
  void initState() {
    super.initState();
    loadFlow();
  }

  Future<void> loadFlow() async {
    setState(() => loading = true);

    final flowData = await supabase
        .from('breeding_flows')
        .select()
        .eq('id', widget.flowId)
        .single();

    final taskData = await supabase
        .from('flow_tasks')
        .select()
        .eq('flow_id', widget.flowId)
        .order('sort_order', ascending: true)
        .order('due_date', ascending: true);

    setState(() {
      flow = Map<String, dynamic>.from(flowData);
      tasks = List<Map<String, dynamic>>.from(taskData);
      loading = false;
    });
    await getOrCreateLitter();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> editTask(Map<String, dynamic> task) async {
    final placeController = TextEditingController(text: task['place'] ?? '');
    final resultController = TextEditingController(text: task['result'] ?? '');
    final notesController = TextEditingController(text: task['notes'] ?? '');
    final isMatingTask = task['task_type'] == 'mating';
    final isMotherWeightTemp =
        task['task_type'] == 'mother_weight_temp';

    final weightController = TextEditingController();
    final tempController = TextEditingController();

    const validMatingTypes = [
      'Natural',
      'TCI',
      'AI',
      'Surgical AI',
      'Fresh Semen',
      'Frozen Semen',
    ];

    String? matingType =
        validMatingTypes.contains(task['result'])
            ? task['result'].toString()
            : null;

    DateTime? selectedDate = task['due_date'] == null
        ? null
        : DateTime.tryParse(task['due_date'].toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task['task_title'] ?? 'Flow Task'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due Date'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'No date set'
                            : selectedDate!.toIso8601String().split('T').first,
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });


                        }
                      },
                    ),

                    /// add split weight and temp
                    if (isMotherWeightTemp) ...[
                      TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Mother weight',
                          suffixText: 'kg',
                        ),
                      ),
                      TextField(
                        controller: tempController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Mother temperature',
                          suffixText: '°C',
                        ),
                      ),
                    ],
                    /// 
                    /// 
                    TextField(
                      controller: placeController,
                      decoration: const InputDecoration(labelText: 'Place'),
                    ),
                    if (isMatingTask)
                      DropdownButtonFormField<String>(
                        value: matingType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Natural',
                            child: Text('Natural'),
                          ),
                          DropdownMenuItem(
                            value: 'TCI',
                            child: Text('TCI'),
                          ),
                          DropdownMenuItem(
                            value: 'AI',
                            child: Text('AI'),
                          ),
                          DropdownMenuItem(
                            value: 'Surgical AI',
                            child: Text('Surgical AI'),
                          ),
                          DropdownMenuItem(
                            value: 'Fresh Semen',
                            child: Text('Fresh Semen'),
                          ),
                          DropdownMenuItem(
                            value: 'Frozen Semen',
                            child: Text('Frozen Semen'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            matingType = value;
                          });
                        },
                      ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    // Special rule: copy ovulation date into real source tables
      final selectedDateText =
      selectedDate?.toIso8601String().split('T').first;

  final updateData = {
    'due_date': selectedDateText,
    'place': placeController.text.trim(),
    'result': isMatingTask
      ? (matingType ?? '')
      : resultController.text.trim(),
    'notes': notesController.text.trim(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  // Special rule: ovulation date must also become actual_date
  if (task['task_type'] == 'ovulation') {
    updateData['actual_date'] = selectedDateText;
  }

  await supabase
      .from('flow_tasks')
      .update(updateData)
      .eq('id', task['id']);
      if (task['task_type'] == 'ala_litter_number') {
        final alaLitterNumber = resultController.text.trim();

        if (alaLitterNumber.isNotEmpty) {
          await supabase.from('breeding_flows').update({
            'ala_litter_number': alaLitterNumber,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', widget.flowId);

          await supabase.from('litters').update({
            'ala_litter_number': alaLitterNumber,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('mating_id', flow?['mating_id']);
        }
      }    

  if (isMotherWeightTemp && task['source_id'] != null) {
    await supabase.from('whelpings').update({
      'arrival_weight': double.tryParse(weightController.text.trim()),
      'arrival_temp': double.tryParse(tempController.text.trim()),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', task['source_id']);
  }

  // Special rule: copy ovulation date into real source tables
  if (task['task_type'] == 'ovulation' && selectedDateText != null) {
      final expectedDueDate = DateTime
          .parse(selectedDateText)
          .add(const Duration(days: 62))
          .toIso8601String()
          .split('T')
          .first;

  await supabase.from('breeding_flows').update({
    'ovulation_date': selectedDateText,
    'expected_due_date': expectedDueDate,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', widget.flowId);

    if (task['source_id'] != null) {
      await supabase.from('matings').update({
        'ovulation_date': selectedDateText,
      }).eq('id', task['source_id']);
    }
  }

  await loadFlow();
  }
/// add puppies
  Future<Map<String, dynamic>?> getOrCreateLitter() async {
    final existing = await supabase
        .from('litters')
        .select()
        .eq('mating_id', flow?['mating_id'])
        .maybeSingle();

    if (existing != null) {
    currentLitter = Map<String, dynamic>.from(existing);
    await loadLitterSettings(currentLitter!['id']);
    return currentLitter;
  }

    final whelpDate = DateTime.now().toIso8601String().split('T').first;

    final litter = await supabase
        .from('litters')
        .insert({
          'litter_name': flow?['flow_name'],
          'short_litter_name': flow?['flow_name'],
          'dam_id': flow?['female_dog_id'],
          'sire_id': flow?['male_dog_id'],
          'dam_ala': flow?['female_dog_ala'],
          'sire_ala': flow?['male_dog_ala'],
          'mating_id': flow?['mating_id'],
          'breeding_plan_id': flow?['breeding_plan_id'],
          'whelp_date': whelpDate,
          'due_date': flow?['expected_due_date'],
          'cycle_start_date': flow?['season_start_date'],
          'ovulation_date': flow?['ovulation_date'],
          'status': 'active',
        })
        .select()
        .single();

        currentLitter = litter;
        await loadLitterSettings(litter['id']);       

    return Map<String, dynamic>.from(litter);

  }

  Future<void> loadLitterSettings(String litterId) async {
    final existing = await supabase
        .from('litter_settings')
        .select()
        .eq('litter_id', litterId)
        .maybeSingle();

    if (!mounted) return;

    if (existing == null) {
      setState(() {
        useDrontal = false;
        useBaycox = false;
        useNailTrimming = false;
        useEns = false;
        usePhotoReminders = false;
      });
      return;
    }

    setState(() {
      litterSettings = existing;
      useDrontal = existing['use_drontal'] == true;
      useBaycox = existing['use_baycox'] == true;
      useNailTrimming = existing['use_nail_trimming'] == true;
      useEns = existing['use_ens'] == true;
      usePhotoReminders = existing['use_photo_reminders'] == true;
    });
  }

  Future<void> saveAndGenerateTasks() async {
    if (currentLitter == null) return;

    final dobRaw = currentLitter!['whelp_date'];
    final eddRaw = flow?['expected_due_date'];

    if (dobRaw == null || eddRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing DOB or EDD')),
      );
      return;
    }

    setState(() => savingLitterSettings = true);

    final settingsData = {
      'litter_id': currentLitter!['id'],
      'flow_id': widget.flowId,
      'use_drontal': useDrontal,
      'use_baycox': useBaycox,
      'use_nail_trimming': useNailTrimming,
      'use_ens': useEns,
      'use_photo_reminders': usePhotoReminders,
    };

    try {
      await supabase.from('litter_settings').upsert(
        settingsData,
        onConflict: 'litter_id',
      );

      await LitterTaskService().generateTasksForLitter(
        flowId: widget.flowId,
        litterId: currentLitter!['id'],
        dob: DateTime.parse(dobRaw),
        expectedDueDate: DateTime.parse(eddRaw),
        settings: settingsData,
      );

      await loadFlow();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasks generated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => savingLitterSettings = false);
      }
    }
  }

////
  Future<void> openLitterPage(String pageType) async {
    final litter = await getOrCreateLitter();
    if (litter == null || !mounted) return;

    if (pageType == 'puppies') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LitterPuppiesPage(litter: litter),
        ),
      );
    }

    if (pageType == 'weights') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LitterWeightsPage(litter: litter),
        ),
      );
    }

    await loadFlow();
  }
///  PRE-Whelping Pending
  Future<void> createPreWhelpingTasksIfNeeded() async {
    final ovulationRaw = flow?['ovulation_date'];

    if (ovulationRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter ovulation date before creating pre-whelping tasks'),
        ),
      );
      return;
    }

    final ovulationDate = DateTime.tryParse(ovulationRaw.toString());
    if (ovulationDate == null) return;

    String dateOnly(DateTime d) => d.toIso8601String().split('T').first;

    final existing = await supabase
        .from('flow_tasks')
        .select('id')
        .eq('flow_id', widget.flowId)
        .inFilter('task_type', [
          'ultrasound',
          'pre_delivery_xray',
          'mother_collection',
          'ala_breeding_notification',
        ]);

    if ((existing as List).isNotEmpty) return;

    final tasksToInsert = [
      {
        'flow_id': widget.flowId,
        'task_group': 'Pre-Whelping',
        'task_title': 'Ultrasound',
        'task_type': 'ultrasound',
        'due_date': dateOnly(ovulationDate.add(const Duration(days: 28))),
        'source_table': 'breeding_flows',
        'source_id': widget.flowId,
        'sort_order': 100,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Pre-Whelping',
        'task_title': 'Pre-delivery X-Ray',
        'task_type': 'pre_delivery_xray',
        'due_date': dateOnly(ovulationDate.add(const Duration(days: 55))),
        'source_table': 'breeding_flows',
        'source_id': widget.flowId,
        'sort_order': 110,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Pre-Whelping',
        'task_title': 'ALA breeding notification',
        'task_type': 'ala_breeding_notification',
        'due_date': dateOnly(ovulationDate.add(const Duration(days: 55))),
        'source_table': 'breeding_flows',
        'source_id': widget.flowId,
        'sort_order': 130,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Pre-Whelping',
        'task_title': 'ALA Litter Number',
        'task_type': 'ala_litter_number',
        'due_date': dateOnly(ovulationDate.add(const Duration(days: 55))),
        'source_table': 'breeding_flows',
        'source_id': widget.flowId,
        'sort_order': 140,
      },

    ];

    await supabase.from('flow_tasks').insert(tasksToInsert);
  }

    ////.  LITTER SETTINGS
    
    Widget _litterSettingsCard() {
      if (currentLitter == null) return const SizedBox.shrink();

      final enabledCount = [
        useDrontal,
        useBaycox,
        useNailTrimming,
        useEns,
        usePhotoReminders,
      ].where((v) => v == true).length;

      return Container(
      key: sectionKeys['Litter Settings'],
      child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: const Text(
              'LITTER SETTINGS',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              enabledCount == 0
                  ? 'No optional care tasks selected'
                  : '$enabledCount optional care item${enabledCount == 1 ? '' : 's'} selected',
            ),
            children: [
              SwitchListTile(
                title: const Text('Drontal'),
                subtitle: const Text('Days 14, 28, 42, 56'),
                value: useDrontal,
                onChanged: (v) => setState(() => useDrontal = v),
              ),

              SwitchListTile(
                title: const Text('Baycox'),
                subtitle: const Text('Day 1, Day 21, Day 28'),
                value: useBaycox,
                onChanged: (v) => setState(() => useBaycox = v),
              ),

              SwitchListTile(
                title: const Text('Nail Trimming'),
                subtitle: const Text('Weekly from Day 7 to Day 56'),
                value: useNailTrimming,
                onChanged: (v) => setState(() => useNailTrimming = v),
              ),

              SwitchListTile(
                title: const Text('ENS'),
                subtitle: const Text('Daily from Day 3 to Day 16'),
                value: useEns,
                onChanged: (v) => setState(() => useEns = v),
              ),

              SwitchListTile(
                title: const Text('Photo Reminders'),
                subtitle: const Text('Weekly puppy photos'),
                value: usePhotoReminders,
                onChanged: (v) => setState(() => usePhotoReminders = v),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: savingLitterSettings ? null : saveAndGenerateTasks,
                  icon: savingLitterSettings
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    savingLitterSettings
                        ? 'Generating Tasks...'
                        : 'Save + Generate Tasks',
                  ),
                ),
              ),
            ],
          ),
        ),
      )
      );
     
    }
//// name in AppBar
  String _flowDisplayName() {
    final female =
        flow?['female_pet_name'] ??
        flow?['female_dog_name'] ??
        flow?['female_dog_ala'] ??
        '';

    final male =
        flow?['male_pet_name'] ??
        flow?['male_dog_name'] ??
        flow?['male_dog_ala'] ??
        '';

    if (female.toString().isNotEmpty &&
        male.toString().isNotEmpty) {
      return '$female × $male';
    }

    return female.toString().isNotEmpty
        ? female.toString()
        : 'Breeding Flow';
  }
///EDD
  String formatDisplayDate(dynamic value) {
    if (value == null) return 'No date set';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'No date set';

    return DateFormat('EEE dd-MM-yyyy').format(date);
  }
///.  add more than 1 mating
  Future<void> addAnotherMating(Map<String, dynamic> task) async {
    final existingMatings = tasks
        .where((t) => t['task_type'] == 'mating')
        .length;

    await supabase.from('flow_tasks').insert({
      'flow_id': widget.flowId,
      'task_group': 'Mating',
      'task_title': 'Mating Event ${existingMatings + 1}',
      'task_type': 'mating',
      'due_date': task['due_date'],
      'source_table': 'matings',
      'source_id': task['source_id'],
      'sort_order': 85 + existingMatings,
      'created_at': DateTime.now().toIso8601String(),
    });
      await loadFlow();
    }
///
  String estimatedDeliveryDate() {
    final ovulationRaw = flow?['ovulation_date'];

    if (ovulationRaw == null) {
      return 'EDD: Ovulation not set';
    }

    final ovulationDate = DateTime.tryParse(ovulationRaw.toString());

    if (ovulationDate == null) {
      return 'EDD: Ovulation not set';
    }

    final edd = ovulationDate.add(const Duration(days: 62));

    return 'EDD: ${formatDisplayDate(edd)}';
  }
  //// Add Delete
  Future<void> deleteTask(Map<String, dynamic> task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Delete "${task['task_title']}" permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase
        .from('flow_tasks')
        .delete()
        .eq('id', task['id']);


    await loadFlow();
  }
  ////. Toggle Complete 
  Future<void> toggleCompleted(Map<String, dynamic> task) async {
    final newValue = task['completed'] != true;

    await supabase.from('flow_tasks').update({
      'completed': newValue,
      'completed_at': newValue ? DateTime.now().toIso8601String() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', task['id']);

    if (newValue == true && task['task_type'] == 'mating') {
      await supabase.from('matings').update({
        'status': 'completed',
      }).eq('id', task['source_id']);

      await supabase.from('breeding_flows').update({
        'current_stage': 'Whelping Pending',
        'status': 'whelping_pending',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.flowId);

      await createPreWhelpingTasksIfNeeded();
    }

    await loadFlow();
  }
  ///. add Whelping card
  Future<void> startWhelping() async {
    final existing = await supabase
        .from('whelpings')
        .select('id')
        .eq('flow_id', widget.flowId)
        .maybeSingle();

    if (existing != null) {
      currentLitter = Map<String, dynamic>.from(existing);
      await loadLitterSettings(currentLitter!['id']);
      return;
    }

    final flowCode = flow?['flow_code']?.toString() ?? 'WHELPING';

    final whelping = await supabase.from('whelpings').insert({
      'flow_id': widget.flowId,
      'mating_id': flow?['mating_id'],
      'breeding_plan_id': flow?['breeding_plan_id'],
      'female_dog_id': flow?['female_dog_id'],
      'male_dog_id': flow?['male_dog_id'],
      'female_dog_ala': flow?['female_dog_ala'],
      'male_dog_ala': flow?['male_dog_ala'],
      'whelping_code': '$flowCode-W01',
      'status': 'started',
    }).select().single();

    await supabase.from('breeding_flows').update({
      'current_stage': 'Whelping',
      'status': 'whelping',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.flowId);

    await supabase.from('flow_tasks').insert([
      {
        'flow_id': widget.flowId,
        'task_group': 'Whelping',
        'task_title': 'Mother arrived at Amity',
        'task_type': 'mother_arrival',
        'source_table': 'whelpings',
        'source_id': whelping['id'],
        'sort_order': 200,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Whelping',
        'task_title': 'Record mother weight and temperature',
        'task_type': 'mother_weight_temp',
        'source_table': 'whelpings',
        'source_id': whelping['id'],
        'sort_order': 210,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Whelping',
        'task_title': 'Record start of whelping',
        'task_type': 'whelping_start',
        'source_table': 'whelpings',
        'source_id': whelping['id'],
        'sort_order': 220,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Whelping',
        'task_title': 'Record puppies',
        'task_type': 'record_puppies',
        'source_table': 'whelpings',
        'source_id': whelping['id'],
        'sort_order': 230,
      },
      {
        'flow_id': widget.flowId,
        'task_group': 'Whelping',
        'task_title': 'Record daily puppy weights',
        'task_type': 'daily_weights',
        'source_table': 'litters',
        'sort_order': 240,
      },
    ]);

    await loadFlow();
  }
  ///
  Future<void> markNotUsed(Map<String, dynamic> task) async {
    await supabase.from('flow_tasks').update({
      'not_used': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', task['id']);

    await loadFlow();
  }
  ///
  Map<String, List<Map<String, dynamic>>> groupedTasks() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final task in tasks) {
      final group = task['task_group']?.toString() ?? 'Other';
      grouped.putIfAbsent(group, () => []);
      grouped[group]!.add(task);
    }

    return grouped;
  }

  @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: flowBackground,
        appBar: AppBar(
          backgroundColor: flowHeader,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The Flow',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      if (flow?['female_dog_id'] == null) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DogDetailsPage(
                            dogId: flow!['female_dog_id'],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          flow?['female_pet_name'] ??
                              flow?['female_dog_ala'] ??
                              'Female',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.contact_page, size: 15),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  InkWell(
                    onTap: () {
                      if (flow?['male_dog_id'] == null) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DogDetailsPage(
                            dogId: flow!['male_dog_id'],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          flow?['male_pet_name'] ??
                              flow?['male_dog_ala'] ??
                              'Male',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.contact_page, size: 15),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadFlow,
                child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                  children: [
                    _flowHeader(),
                    const SizedBox(height: 12),

                    _flowTimelineCard(),
                    const SizedBox(height: 12),

                    if (groupedTasks()['Season'] != null)
                      _taskGroup('Season', groupedTasks()['Season']!),

                    if (groupedTasks()['Mating'] != null)
                      _taskGroup('Mating', groupedTasks()['Mating']!),

                    if (groupedTasks()['Pre-Whelping'] != null)
                      _taskGroup('Pre-Whelping', groupedTasks()['Pre-Whelping']!),

                    _litterSettingsCard(),

                    if (groupedTasks()['Whelping'] != null)
                      _taskGroup('Whelping', groupedTasks()['Whelping']!),

                    if (groupedTasks()['Puppy Care'] != null)
                      _taskGroup('Puppy Care', groupedTasks()['Puppy Care']!),

                    ...groupedTasks().entries
                         .where((entry) => ![
                              'Season',
                              'Progesterone',
                              'Ovulation',
                              'Mating',
                              'Pre-Whelping',
                              'Whelping',
                              'Puppy Care',
                            ].contains(entry.key))
                        .map((entry) => _taskGroup(entry.key, entry.value)),
                  ],
                ),
              ),
      );
    }
  
  void _jumpToSection(String section) {
    final key = sectionKeys[section];

    if (key?.currentContext == null) return;

    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  Widget _flowTimelineCard() {
    final stageOrder = [
      {
        'label': 'Season',
        'icon': Icons.water_drop,
        'group': 'Season',
      },
      {
        'label': 'Progesterone',
        'icon': Icons.science,
        'group': 'Progesterone',
      },
      {
        'label': 'Ovulation',
        'icon': Icons.egg_alt,
        'group': 'Ovulation',
      },
      {
        'label': 'Mating',
        'icon': Icons.favorite,
        'group': 'Mating',
      },
      {
        'label': 'Pre-Whelping',
        'icon': Icons.event_note,
        'group': 'Pre-Whelping',
      },
      {
        'label': 'Whelping',
        'icon': Icons.child_care,
        'group': 'Whelping',
      },
      {
        'label': 'Puppy Care',
        'icon': Icons.pets,
        'group': 'Puppy Care',
      },
    ];

    final grouped = groupedTasks();

    int currentIndex = 0;

    for (int i = 0; i < stageOrder.length; i++) {
      final groupName = stageOrder[i]['group'] as String;
      final groupTasks = grouped[groupName] ?? [];

      final hasIncomplete = groupTasks.any((t) => t['completed'] != true);

      if (groupTasks.isNotEmpty && hasIncomplete) {
        currentIndex = i;
        break;
      }

      if (i == stageOrder.length - 1) {
        currentIndex = i;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(stageOrder.length, (index) {
              final stage = stageOrder[index];
              final label = stage['label'] as String;
              final icon = stage['icon'] as IconData;

              final groupedTasksForStage =
                  grouped[stage['group'] as String] ?? [];

              final isComplete = groupedTasksForStage.isNotEmpty &&
                  groupedTasksForStage.every((t) => t['completed'] == true);

              final isCurrent = index == currentIndex;
              final isFuture = index > currentIndex;

              final color = isComplete
                  ? Colors.grey
                  : isCurrent
                      ? Colors.deepOrange
                      : Colors.grey.shade300;

              return Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _jumpToSection(label);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color,
                          child: Icon(
                            icon,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isFuture ? Colors.grey : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (index != stageOrder.length - 1)
                    Container(
                      width: 32,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: index < currentIndex
                          ? Colors.grey
                          : Colors.grey.shade300,
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }


  Widget _flowHeader() {
    final female = flow?['female_dog_ala'] ?? '';
    final male = flow?['male_dog_ala'] ?? '';
    final stage = flow?['current_stage'] ?? '';
    final status = flow?['status'] ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: flowHeader,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THE FLOW',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$female × $male',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Stage: $stage'),
          Text('Status: $status'),
          if (flow?['season_start_date'] != null)
            Text(
              'Season Start: ${formatDisplayDate(flow!['season_start_date'])}',
            ),
          Text(
            estimatedDeliveryDate(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (flow?['status'] == 'whelping_pending')
            ElevatedButton.icon(
              onPressed: startWhelping,
              icon: const Icon(Icons.child_care),
              label: const Text('Start Whelping'),
            ),
          

        ],
      ),
    );
  }

  Widget _taskGroup(String title, List<Map<String, dynamic>> groupTasks) {
    final incompleteCount =
        groupTasks.where((t) => t['completed'] != true).length;
        final allComplete = incompleteCount == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: allComplete ? Colors.green.shade50 : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ExpansionTile(
          initiallyExpanded: !allComplete,
       //    title == 'Season' || title == 'Mating',
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          title: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            incompleteCount == 0
                ? 'All complete'
                : '$incompleteCount item${incompleteCount == 1 ? '' : 's'} remaining',
          ),
          children: groupTasks.map(_taskTile).toList(),
        ),
      ),
    );
  }

  Widget _taskTile(Map<String, dynamic> task) {
    final completed = task['completed'] == true;

    final canSkip = [
          'progesterone',
          'progesterone_test',
          'ultrasound',
          'pre_delivery_xray',
          'ala_breeding_notification',
        ].contains(task['task_type']) &&
        task['not_used'] != true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: completed,
            onChanged: (_) => toggleCompleted(task),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['task_title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),

                if (task['due_date'] != null)
                  Text('Due: ${formatDisplayDate(task['due_date'])}'),

                if ((task['place'] ?? '').toString().isNotEmpty)
                  Text('Place: ${task['place']}'),

                if ((task['result'] ?? '').toString().isNotEmpty)
                  Text('Result: ${task['result']}'),

                if ((task['notes'] ?? '').toString().isNotEmpty)
                  Text('Notes: ${task['notes']}'),

                if (task['task_type'] == 'mating')
                  TextButton.icon(
                    onPressed: () => addAnotherMating(task),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another'),
                  ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    if (canSkip)
                      TextButton.icon(
                        onPressed: () => markNotUsed(task),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Skip'),
                      ),

                    if (task['task_type'] == 'record_puppies')
                      TextButton.icon(
                        onPressed: () => openLitterPage('puppies'),
                        icon: const Icon(Icons.pets, size: 16),
                        label: const Text('Puppies'),
                      ),

                    if (task['task_type'] == 'daily_weights')
                      TextButton.icon(
                        onPressed: () => openLitterPage('weights'),
                        icon: const Icon(Icons.monitor_weight, size: 16),
                        label: const Text('Weights'),
                      ),

                    if (!['record_puppies', 'daily_weights']
                        .contains(task['task_type']))
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => editTask(task),
                      ),

                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => deleteTask(task),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}