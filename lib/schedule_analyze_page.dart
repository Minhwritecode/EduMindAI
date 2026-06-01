import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/notebook_context_state.dart';
import 'services/schedule_service.dart' as svc;
import 'services/notebook_mongo_sync.dart' as nb_sync;

class ScheduleAnalyzePage extends StatefulWidget {
  const ScheduleAnalyzePage({super.key});

  @override
  State<ScheduleAnalyzePage> createState() => _ScheduleAnalyzePageState();
}

class _ScheduleAnalyzePageState extends State<ScheduleAnalyzePage> {
  bool _isLoading = true;
  List<svc.TimetableDay> _timetable = [];
  List<nb_sync.Notebook> _notebooks = [];
  
  // Display settings
  final double _hourHeight = 70.0;
  final int _startHour = 7; // 07:00
  final int _endHour = 19;  // 19:00
  
  // Colors mimicking the image
  final List<Color> _cardColors = [
    const Color(0xFF335C4B), // Dark green
    const Color(0xFF3A4B59), // Dark slate blue
    const Color(0xFF5C4738), // Brown
    const Color(0xFF5C3336), // Dark red
    const Color(0xFF485C33), // Olive green
    const Color(0xFF5C335A), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = context.read<NotebookContextState>().userId;
    
    final (schedule, _) = await svc.ScheduleService.fetchSchedule(userId);
    if (schedule != null) {
      _timetable = schedule.timetable;
    } else {
      _timetable = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ].map((d) => svc.TimetableDay(dayOfWeek: d, slots: [])).toList();
    }

    final (notebooks, _) = await nb_sync.NotebookMongoSync.fetchNotebooks(userId);
    if (notebooks != null) {
      _notebooks = notebooks;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _getColorForSubject(String subject) {
    int hash = subject.hashCode;
    return _cardColors[hash.abs() % _cardColors.length];
  }

  String _mapDayToVietnamese(String englishDay) {
    switch (englishDay.toLowerCase()) {
      case 'monday': return 'HAI';
      case 'tuesday': return 'BA';
      case 'wednesday': return 'TƯ';
      case 'thursday': return 'NĂM';
      case 'friday': return 'SÁU';
      case 'saturday': return 'BẢY';
      case 'sunday': return 'CN';
      default: return englishDay.toUpperCase();
    }
  }

  // Parses "HH:MM" into total minutes from startHour
  int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? _startHour;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h - _startHour) * 60 + m;
  }

  void _showSlotDialog({svc.TimeSlot? existingSlot, String? dayOfWeek}) {
    final isEditing = existingSlot != null;
    final subjectCtrl = TextEditingController(text: existingSlot?.subject ?? '');
    final roomCtrl = TextEditingController(text: existingSlot?.roomOrLink ?? '');
    
    int selectedStartPeriod = 1;
    int selectedEndPeriod = 2;

    if (existingSlot != null) {
      final sh = int.tryParse(existingSlot.startTime.split(':').first) ?? _startHour;
      final eh = int.tryParse(existingSlot.endTime.split(':').first) ?? (_startHour + 1);
      selectedStartPeriod = (sh - _startHour) + 1;
      selectedEndPeriod = (eh - _startHour);
      if (selectedEndPeriod < selectedStartPeriod) selectedEndPeriod = selectedStartPeriod;
    }

    String selectedDay = dayOfWeek ?? (existingSlot != null ? _timetable.firstWhere((d) => d.slots.contains(existingSlot)).dayOfWeek : 'Monday');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Cập nhật Lịch Học' : 'Thêm Lịch Học'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(labelText: 'Thứ trong tuần'),
                      items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedDay = v!),
                    ),
                    TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Môn học / Chủ đề')),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedStartPeriod,
                            decoration: const InputDecoration(labelText: 'Bắt đầu'),
                            items: List.generate((_endHour - _startHour), (index) {
                              final tiet = index + 1;
                              return DropdownMenuItem(value: tiet, child: Text('Tiết $tiet'));
                            }),
                            onChanged: (v) {
                              setDialogState(() {
                                selectedStartPeriod = v!;
                                if (selectedEndPeriod < selectedStartPeriod) {
                                  selectedEndPeriod = selectedStartPeriod;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedEndPeriod,
                            decoration: const InputDecoration(labelText: 'Kết thúc'),
                            items: List.generate((_endHour - _startHour), (index) {
                              final tiet = index + 1;
                              return DropdownMenuItem(value: tiet, child: Text('Tiết $tiet'));
                            }),
                            onChanged: (v) {
                              setDialogState(() {
                                selectedEndPeriod = v!;
                                if (selectedStartPeriod > selectedEndPeriod) {
                                  selectedStartPeriod = selectedEndPeriod;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Phòng học / Link Zoom')),
                  ],
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteSlot(selectedDay, existingSlot);
                    },
                    child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
                  onPressed: () async {
                    if (subjectCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);

                    final st = (_startHour + selectedStartPeriod - 1).toString().padLeft(2, '0');
                    final et = (_startHour + selectedEndPeriod).toString().padLeft(2, '0');

                    final newSlot = svc.TimeSlot(
                      startTime: '$st:00',
                      endTime: '$et:00',
                      subject: subjectCtrl.text.trim(),
                      roomOrLink: roomCtrl.text.trim(),
                      notebookId: '', // Notebook attachment removed
                    );

                    await _saveSlot(isEditing ? existingSlot : null, newSlot, selectedDay);
                  },
                  child: Text(isEditing ? 'Cập nhật' : 'Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveSlot(svc.TimeSlot? oldSlot, svc.TimeSlot newSlot, String targetDay) async {
    setState(() => _isLoading = true);

    // Remove old slot if it exists
    if (oldSlot != null) {
      for (var day in _timetable) {
        day.slots.removeWhere((s) => s == oldSlot);
      }
    }

    // Add new slot
    var dayObj = _timetable.firstWhere((d) => d.dayOfWeek == targetDay, orElse: () {
      final newDay = svc.TimetableDay(dayOfWeek: targetDay, slots: []);
      _timetable.add(newDay);
      return newDay;
    });
    dayObj.slots.add(newSlot);

    final userId = context.read<NotebookContextState>().userId;
    final err = await svc.ScheduleService.updateTimetable(userId, _timetable);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $err')));
    }
    await _loadData();
  }

  Future<void> _deleteSlot(String dayOfWeek, svc.TimeSlot slot) async {
    setState(() => _isLoading = true);
    
    final dayObj = _timetable.firstWhere((d) => d.dayOfWeek == dayOfWeek);
    dayObj.slots.removeWhere((s) => s == slot);

    final userId = context.read<NotebookContextState>().userId;
    final err = await svc.ScheduleService.updateTimetable(userId, _timetable);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $err')));
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSlotDialog(),
        backgroundColor: const Color(0xFF48A9A6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF48A9A6)))
          : Column(
              children: [
                _buildHeaderRow(),
                const Divider(height: 1, thickness: 1, color: Colors.white10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimeColumn(),
                        const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                        Expanded(child: _buildGrid()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderRow() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: const Color(0xFF1E1F22),
      child: Row(
        children: [
          const SizedBox(width: 50), // Matches time column width
          ...days.map((day) => Expanded(
                child: Column(
                  children: [
                    Text(
                      _mapDayToVietnamese(day),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE3E3E3), fontSize: 13),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    final periods = _endHour - _startHour;
    return SizedBox(
      width: 50,
      child: Column(
        children: List.generate(periods, (index) {
          return Container(
            height: _hourHeight,
            alignment: Alignment.topCenter,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Text(
                  'TIẾT\n${index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGrid() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final totalHeight = (_endHour - _startHour) * _hourHeight;

    return SizedBox(
      height: totalHeight,
      child: Row(
        children: days.map((dayName) {
          final dayData = _timetable.firstWhere((d) => d.dayOfWeek == dayName, orElse: () => svc.TimetableDay(dayOfWeek: dayName, slots: []));
          
          return Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white10),
                ),
                color: Color(0xFF131314), // Dark background for empty grid
              ),
              child: Stack(
                children: [
                  // Draw horizontal grid lines
                  for (int i = 0; i < (_endHour - _startHour); i++)
                    Positioned(
                      top: i * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: _hourHeight,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white10)),
                        ),
                      ),
                    ),
                  
                  // Draw class cards
                  ...dayData.slots.map((slot) {
                    final startMins = _parseTimeToMinutes(slot.startTime);
                    final endMins = _parseTimeToMinutes(slot.endTime);
                    final top = (startMins / 60) * _hourHeight;
                    final height = ((endMins - startMins) / 60) * _hourHeight;
                    
                    if (top < 0 || top >= totalHeight || height <= 0) return const SizedBox();

                    return Positioned(
                      top: top,
                      left: 1,
                      right: 1,
                      height: height,
                      child: GestureDetector(
                        onTap: () => _showSlotDialog(existingSlot: slot, dayOfWeek: dayName),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _getColorForSubject(slot.subject),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slot.subject,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (slot.roomOrLink.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  slot.roomOrLink,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
