import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kalender/kalender.dart';
import 'state/notebook_context_state.dart';
import 'services/schedule_service.dart' as svc;

class ScheduleAnalyzePage extends StatefulWidget {
  const ScheduleAnalyzePage({super.key});

  @override
  State<ScheduleAnalyzePage> createState() => _ScheduleAnalyzePageState();
}

class _ScheduleAnalyzePageState extends State<ScheduleAnalyzePage> {
  bool _isLoading = true;
  List<svc.TimetableDay> _timetable = [];
  
  // Kalender controllers & state
  static const int _startHour = 7; // 07:00
  static const int _endHour = 19;  // 19:00
  late final eventsController = DefaultEventsController();
  late final calendarController = CalendarController();
  late final displayRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 180)),
    end: DateTime.now().add(const Duration(days: 180)),
  );
  
  late final DemoConfiguration configuration;
  bool _showConfig = true;
  String _selectedTimezone = 'ICT';

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
    configuration = DemoConfiguration(displayRange: displayRange);
    _loadData();
  }

  @override
  void dispose() {
    configuration.dispose();
    eventsController.dispose();
    super.dispose();
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

    _generateEvents();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _generateEvents() {
    eventsController.clearEvents();
    
    final List<CalendarEvent> events = [];
    DateTime current = displayRange.start;
    final end = displayRange.end;
    
    final Map<int, String> weekdayToName = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    
    while (current.isBefore(end)) {
      final dayName = weekdayToName[current.weekday];
      if (dayName != null) {
        final dayData = _timetable.firstWhere(
          (d) => d.dayOfWeek.toLowerCase() == dayName.toLowerCase(),
          orElse: () => svc.TimetableDay(dayOfWeek: dayName, slots: []),
        );
        
        for (var slot in dayData.slots) {
          final startParts = slot.startTime.split(':');
          final endParts = slot.endTime.split(':');
          
          if (startParts.length == 2 && endParts.length == 2) {
            final startHour = int.tryParse(startParts[0]) ?? 0;
            final startMin = int.tryParse(startParts[1]) ?? 0;
            final endHour = int.tryParse(endParts[0]) ?? 0;
            final endMin = int.tryParse(endParts[1]) ?? 0;
            
            final eventStart = DateTime(current.year, current.month, current.day, startHour, startMin);
            final eventEnd = DateTime(current.year, current.month, current.day, endHour, endMin);
            
            if (eventEnd.isAfter(eventStart)) {
              events.add(
                TimetableEvent(
                  dateTimeRange: DateTimeRange(start: eventStart, end: eventEnd),
                  slot: slot,
                  dayOfWeek: dayData.dayOfWeek,
                ),
              );
            }
          }
        }
      }
      current = current.add(const Duration(days: 1));
    }
    
    eventsController.addEvents(events);
  }

  Future<void> _handleEventChanged(CalendarEvent event, CalendarEvent updatedEvent) async {
    if (event is! TimetableEvent || updatedEvent is! TimetableEvent) return;
    
    final oldSlot = event.slot;
    final oldDay = event.dayOfWeek;
    
    final localStart = updatedEvent.dateTimeRange.start.toLocal();
    final localEnd = updatedEvent.dateTimeRange.end.toLocal();
    final startStr = '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
    final endStr = '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}';
    
    final Map<int, String> weekdayToName = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    final newDay = weekdayToName[localStart.weekday] ?? oldDay;
    
    final newSlot = svc.TimeSlot(
      startTime: startStr,
      endTime: endStr,
      subject: oldSlot.subject,
      roomOrLink: oldSlot.roomOrLink,
      notebookId: oldSlot.notebookId,
    );
    
    for (var day in _timetable) {
      day.slots.removeWhere((s) => s == oldSlot);
    }
    
    final targetDayObj = _timetable.firstWhere((d) => d.dayOfWeek.toLowerCase() == newDay.toLowerCase());
    targetDayObj.slots.add(newSlot);
    
    setState(() => _isLoading = true);
    final userId = context.read<NotebookContextState>().userId;
    final err = await svc.ScheduleService.updateTimetable(userId, _timetable);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $err')));
    }
    await _loadData();
  }

  void _showCreatedEventDialog(TimetableEvent event) {
    final localStart = event.dateTimeRange.start.toLocal();
    final localEnd = event.dateTimeRange.end.toLocal();
    
    final Map<int, String> weekdayToName = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    final dayOfWeek = weekdayToName[localStart.weekday] ?? 'Monday';
    
    final tempSlot = svc.TimeSlot(
      startTime: '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}',
      endTime: '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}',
      subject: '',
      roomOrLink: '',
      notebookId: '',
    );
    
    _showSlotDialog(existingSlot: null, dayOfWeek: dayOfWeek, initialTempSlot: tempSlot);
  }

  Color _eventColor(CalendarEvent event) {
    if (event is TimetableEvent) {
      return _getColorForSubject(event.slot.subject);
    }
    return const Color(0xFF48A9A6);
  }

  TileComponents _tileComponents() {
    final radius = BorderRadius.circular(6);

    return TileComponents(
      tileBuilder: (event, tileRange) {
        final slot = (event is TimetableEvent) ? event.slot : null;
        final color = _eventColor(event);
        
        return Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: radius,
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slot?.subject ?? '',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (slot != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${slot.startTime} - ${slot.endTime}',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (slot.roomOrLink.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    slot.roomOrLink,
                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ],
          ),
        );
      },
      dropTargetTile: (event) {
        final color = _eventColor(event);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            borderRadius: radius,
          ),
        );
      },
      feedbackTileBuilder: (event, size) {
        final color = _eventColor(event);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size.width * 0.85,
          height: size.height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: radius,
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
        );
      },
      tileWhenDraggingBuilder: (event) {
        final color = _eventColor(event);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            border: Border(left: BorderSide(color: color.withOpacity(0.3), width: 4)),
            borderRadius: radius,
          ),
        );
      },
      dragAnchorStrategy: (draggable, context, position) {
        final renderBox = context.findRenderObject()! as RenderBox;
        return Offset(20, renderBox.size.height / 2);
      },
      verticalResizeHandle: const ResizeHandle.vertical(),
      horizontalResizeHandle: const ResizeHandle.horizontal(),
    );
  }

  ScheduleTileComponents _scheduleTileComponents() {
    final radius = BorderRadius.circular(6);

    return ScheduleTileComponents(
      tileBuilder: (event, tileRange) {
        final slot = (event is TimetableEvent) ? event.slot : null;
        final color = _eventColor(event);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          color: color.withOpacity(0.18),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: color.withOpacity(0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot?.subject ?? '',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (slot != null && slot.roomOrLink.isNotEmpty)
                        Text(
                          slot.roomOrLink,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${slot?.startTime} - ${slot?.endTime}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
      dropTargetTile: (event) {
        final color = _eventColor(event);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            borderRadius: radius,
          ),
        );
      },
      feedbackTileBuilder: (event, size) {
        final color = _eventColor(event);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size.width * 0.85,
          height: size.height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: radius,
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
        );
      },
      tileWhenDraggingBuilder: (event) {
        final color = _eventColor(event);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            border: Border(left: BorderSide(color: color.withOpacity(0.3), width: 4)),
            borderRadius: radius,
          ),
        );
      },
      dragAnchorStrategy: (draggable, context, position) {
        final renderBox = context.findRenderObject()! as RenderBox;
        return Offset(20, renderBox.size.height / 2);
      },
    );
  }

  CalendarComponents _components(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.outlineVariant.withOpacity(0.15);
    final mutedText = TextStyle(color: cs.onSurfaceVariant);
    return CalendarComponents(
      multiDayComponentStyles: MultiDayComponentStyles(
        headerStyles: MultiDayHeaderComponentStyles(
          dayHeaderStyle: DayHeaderStyle(
            textStyle: mutedText,
            numberTextStyle: mutedText,
          ),
        ),
        bodyStyles: MultiDayBodyComponentStyles(
          hourLinesStyle: HourLinesStyle(color: lineColor),
          daySeparatorStyle: DaySeparatorStyle(color: lineColor),
        ),
      ),
      monthComponentStyles: MonthComponentStyles(
        bodyStyles: MonthBodyComponentStyles(
          monthGridStyle: MonthGridStyle(color: lineColor),
        ),
      ),
    );
  }

  Color _getColorForSubject(String subject) {
    int hash = subject.hashCode;
    return _cardColors[hash.abs() % _cardColors.length];
  }


  void _showSlotDialog({
    svc.TimeSlot? existingSlot,
    String? dayOfWeek,
    svc.TimeSlot? initialTempSlot,
  }) {
    final isEditing = existingSlot != null;
    final subjectCtrl = TextEditingController(text: existingSlot?.subject ?? initialTempSlot?.subject ?? '');
    final roomCtrl = TextEditingController(text: existingSlot?.roomOrLink ?? initialTempSlot?.roomOrLink ?? '');
    
    int selectedStartPeriod = 1;
    int selectedEndPeriod = 2;

    final sourceSlot = existingSlot ?? initialTempSlot;
    if (sourceSlot != null && sourceSlot.startTime.isNotEmpty) {
      final sh = int.tryParse(sourceSlot.startTime.split(':').first) ?? _startHour;
      final eh = int.tryParse(sourceSlot.endTime.split(':').first) ?? (_startHour + 1);
      selectedStartPeriod = (sh - _startHour) + 1;
      selectedEndPeriod = (eh - _startHour);
      if (selectedStartPeriod < 1) selectedStartPeriod = 1;
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

  Widget _buildCustomToolbar() {
    return Container(
      color: const Color(0xFF1E1F22),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ValueListenableBuilder<DateTimeRange?>(
            valueListenable: calendarController.visibleDateTimeRange,
            builder: (context, value, child) {
              if (value == null) return const SizedBox.shrink();
              final date = value.start;
              return OutlinedButton.icon(
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: displayRange.start,
                    lastDate: displayRange.end,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xFF48A9A6),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (selectedDate != null) {
                    calendarController.animateToDate(selectedDate);
                  }
                },
                icon: const Icon(Icons.calendar_month, color: Color(0xFF48A9A6), size: 18),
                label: Text(
                  'Tháng ${date.month}, ${date.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE3E3E3)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFFE3E3E3)),
            onPressed: () => calendarController.animateToPreviousPage(),
            tooltip: 'Trang trước',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFFE3E3E3)),
            onPressed: () => calendarController.animateToNextPage(),
            tooltip: 'Trang sau',
          ),
          const SizedBox(width: 4),
          FilledButton.tonalIcon(
            onPressed: () => calendarController.animateToDate(DateTime.now()),
            icon: const Icon(Icons.today, size: 18),
            label: const Text('Hôm nay'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF48A9A6).withOpacity(0.15),
              foregroundColor: const Color(0xFF48A9A6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          // Timezone mock selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.public, color: Color(0xFF48A9A6), size: 16),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTimezone,
                    dropdownColor: const Color(0xFF1E1F22),
                    style: const TextStyle(color: Color(0xFFE3E3E3), fontSize: 13),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF48A9A6), size: 16),
                    items: const [
                      DropdownMenuItem(value: 'ICT', child: Text('Giờ Đông Dương')),
                      DropdownMenuItem(value: 'UTC', child: Text('Giờ Quốc tế (UTC)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTimezone = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // View selector dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.view_agenda, color: Color(0xFF48A9A6), size: 16),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ViewConfiguration>(
                    dropdownColor: const Color(0xFF1E1F22),
                    value: configuration.viewConfiguration,
                    style: const TextStyle(color: Color(0xFFE3E3E3), fontSize: 13),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF48A9A6), size: 16),
                    items: configuration.viewConfigurations.map((config) {
                      return DropdownMenuItem<ViewConfiguration>(
                        value: config,
                        child: Text(config.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          configuration.viewConfiguration = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Toggle config button
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _showConfig ? const Color(0xFF48A9A6) : const Color(0xFFE3E3E3),
            ),
            onPressed: () => setState(() => _showConfig = !_showConfig),
            tooltip: 'Cấu hình',
            style: IconButton.styleFrom(
              backgroundColor: _showConfig ? const Color(0xFF48A9A6).withOpacity(0.15) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
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
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildCustomToolbar(),
                      Expanded(
                        child: ZoomDetector(
                          controller: calendarController,
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              configuration.viewConfigurationNotifier,
                            ]),
                            builder: (context, _) {
                              return CalendarView(
                                eventsController: eventsController,
                                calendarController: calendarController,
                                viewConfiguration: configuration.viewConfiguration,
                                components: _components(context),
                                callbacks: CalendarCallbacks(
                                  onEventTapped: (event, renderBox) {
                                    if (event is TimetableEvent) {
                                      _showSlotDialog(existingSlot: event.slot, dayOfWeek: event.dayOfWeek);
                                    }
                                  },
                                  onEventChanged: (event, updatedEvent) async {
                                    await _handleEventChanged(event, updatedEvent);
                                  },
                                  onEventCreate: (event) {
                                    return TimetableEvent(
                                      dateTimeRange: event.dateTimeRange,
                                      slot: svc.TimeSlot(
                                        startTime: '',
                                        endTime: '',
                                        subject: 'Môn học mới',
                                        roomOrLink: '',
                                        notebookId: '',
                                      ),
                                      dayOfWeek: '',
                                    );
                                  },
                                  onEventCreated: (event) async {
                                    if (event is TimetableEvent) {
                                      _showCreatedEventDialog(event);
                                    }
                                  },
                                  onLongPressedWithDetail: (TapDetail detail) {
                                    final range = switch (detail) {
                                      DayDetail d => DateTimeRange(start: d.date, end: d.date.add(const Duration(minutes: 60))),
                                      MultiDayDetail d => d.dateTimeRange,
                                      _ => null,
                                    };
                                    if (range != null) {
                                      final event = TimetableEvent(
                                        dateTimeRange: range,
                                        slot: svc.TimeSlot(
                                          startTime: '',
                                          endTime: '',
                                          subject: 'Môn học mới',
                                          roomOrLink: '',
                                          notebookId: '',
                                        ),
                                        dayOfWeek: '',
                                      );
                                      _showCreatedEventDialog(event);
                                    }
                                  },
                                ),
                                header: ListenableBuilder(
                                  listenable: configuration.showHeaderNotifier,
                                  builder: (context, _) {
                                    if (!configuration.showHeader) return const SizedBox.shrink();
                                    return ListenableBuilder(
                                      listenable: Listenable.merge([
                                        configuration.interactionHeader,
                                        configuration.multiDayHeaderConfigurationNotifier,
                                      ]),
                                      builder: (context, _) {
                                        return Container(
                                          padding: const EdgeInsets.only(top: 4),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.white10,
                                              ),
                                            ),
                                          ),
                                          child: CalendarHeader(
                                            multiDayTileComponents: _tileComponents(),
                                            multiDayHeaderConfiguration: configuration.multiDayHeaderConfiguration,
                                            interaction: configuration.interactionHeader.value,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                body: ListenableBuilder(
                                  listenable: Listenable.merge([
                                    configuration.interactionBody,
                                    configuration.snapping,
                                    configuration.multiDayBodyConfigurationNotifier,
                                    configuration.monthBodyConfigurationNotifier,
                                  ]),
                                  builder: (context, _) {
                                    return CalendarBody(
                                      multiDayTileComponents: _tileComponents(),
                                      monthTileComponents: _tileComponents(),
                                      multiDayBodyConfiguration: configuration.multiDayBodyConfiguration,
                                      monthBodyConfiguration: configuration.monthBodyConfiguration,
                                      scheduleTileComponents: _scheduleTileComponents(),
                                      interaction: configuration.interactionBody.value,
                                      snapping: configuration.snapping.value,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.centerLeft,
                  child: _showConfig
                      ? SizedBox(
                          width: 320,
                          height: double.infinity,
                          child: ConfigurationPanel(
                            configuration: configuration,
                            onDismiss: () => setState(() => _showConfig = false),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
    );
  }
}

class TimetableEvent extends CalendarEvent {
  final svc.TimeSlot slot;
  final String dayOfWeek;

  TimetableEvent({
    required super.dateTimeRange,
    required this.slot,
    required this.dayOfWeek,
  });

  @override
  TimetableEvent copyWith({
    DateTimeRange? dateTimeRange,
    EventInteraction? interaction,
    svc.TimeSlot? slot,
    String? dayOfWeek,
  }) {
    final newEvent = TimetableEvent(
      dateTimeRange: dateTimeRange ?? this.dateTimeRange,
      slot: slot ?? this.slot,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    );
    newEvent.id = id;
    return newEvent;
  }
}

class ResizeHandle extends StatefulWidget {
  final Axis axis;
  const ResizeHandle({super.key, required this.axis});
  const ResizeHandle.vertical({super.key}) : axis = Axis.vertical;
  const ResizeHandle.horizontal({super.key}) : axis = Axis.horizontal;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: widget.axis == Axis.vertical
          ? const EdgeInsets.symmetric(vertical: 3, horizontal: 6)
          : const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: BoxDecoration(
        color: hovering ? color : color.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      height: widget.axis == Axis.vertical ? 4 : double.infinity,
      width: widget.axis == Axis.horizontal ? 4 : double.infinity,
    );

    return MouseRegion(
      cursor: widget.axis == Axis.vertical
          ? SystemMouseCursors.resizeUpDown
          : SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: child,
    );
  }
}

class DemoConfiguration extends ChangeNotifier {
  final DateTimeRange displayRange;

  DemoConfiguration({required this.displayRange}) {
    viewConfigurations = [
      MultiDayViewConfiguration.week(
        name: 'Tuần',
        displayRange: displayRange,
        firstDayOfWeek: 1,
        timeOfDayRange: TimeOfDayRange(
          start: const TimeOfDay(hour: 7, minute: 0),
          end: const TimeOfDay(hour: 19, minute: 0),
        ),
      ),
      MultiDayViewConfiguration.singleDay(
        name: 'Ngày',
        displayRange: displayRange,
        timeOfDayRange: TimeOfDayRange(
          start: const TimeOfDay(hour: 7, minute: 0),
          end: const TimeOfDay(hour: 19, minute: 0),
        ),
      ),
      MonthViewConfiguration.singleMonth(
        name: 'Tháng',
        displayRange: displayRange,
      ),
      ScheduleViewConfiguration.continuous(
        name: 'Lịch trình',
        displayRange: displayRange,
      ),
    ];
    viewConfigurationNotifier = ValueNotifier(viewConfigurations[0]);
  }

  late final List<ViewConfiguration> viewConfigurations;
  late final ValueNotifier<ViewConfiguration> viewConfigurationNotifier;

  ViewConfiguration get viewConfiguration => viewConfigurationNotifier.value;
  set viewConfiguration(ViewConfiguration value) {
    if (viewConfigurationNotifier.value == value) return;
    viewConfigurationNotifier.value = value;
    notifyListeners();
  }

  final multiDayBodyConfigurationNotifier = ValueNotifier(const MultiDayBodyConfiguration());
  MultiDayBodyConfiguration get multiDayBodyConfiguration => multiDayBodyConfigurationNotifier.value;
  set multiDayBodyConfiguration(MultiDayBodyConfiguration value) {
    if (multiDayBodyConfigurationNotifier.value == value) return;
    multiDayBodyConfigurationNotifier.value = value;
    notifyListeners();
  }

  final multiDayHeaderConfigurationNotifier = ValueNotifier(const MultiDayHeaderConfiguration());
  MultiDayHeaderConfiguration get multiDayHeaderConfiguration => multiDayHeaderConfigurationNotifier.value;
  set multiDayHeaderConfiguration(MultiDayHeaderConfiguration value) {
    if (multiDayHeaderConfigurationNotifier.value == value) return;
    multiDayHeaderConfigurationNotifier.value = value;
    notifyListeners();
  }

  final monthBodyConfigurationNotifier = ValueNotifier(const MonthBodyConfiguration());
  MonthBodyConfiguration get monthBodyConfiguration => monthBodyConfigurationNotifier.value;
  set monthBodyConfiguration(MonthBodyConfiguration value) {
    if (monthBodyConfigurationNotifier.value == value) return;
    monthBodyConfigurationNotifier.value = value;
    notifyListeners();
  }

  final scheduleBodyConfigurationNotifier = ValueNotifier(ScheduleBodyConfiguration());
  ScheduleBodyConfiguration get scheduleBodyConfiguration => scheduleBodyConfigurationNotifier.value;
  set scheduleBodyConfiguration(ScheduleBodyConfiguration value) {
    if (scheduleBodyConfigurationNotifier.value == value) return;
    scheduleBodyConfigurationNotifier.value = value;
    notifyListeners();
  }

  final ValueNotifier<CalendarInteraction> interactionHeader = ValueNotifier(CalendarInteraction(
    allowResizing: true,
    allowRescheduling: true,
    allowEventCreation: true,
  ));

  final ValueNotifier<CalendarInteraction> interactionBody = ValueNotifier(CalendarInteraction(
    allowResizing: true,
    allowRescheduling: true,
    allowEventCreation: true,
  ));

  final ValueNotifier<CalendarSnapping> snapping = ValueNotifier(const CalendarSnapping());

  final ValueNotifier<bool> showHeaderNotifier = ValueNotifier(true);
  bool get showHeader => showHeaderNotifier.value;
  set showHeader(bool value) {
    if (showHeaderNotifier.value == value) return;
    showHeaderNotifier.value = value;
    notifyListeners();
  }
}

class ConfigurationPanel extends StatelessWidget {
  final DemoConfiguration configuration;
  final VoidCallback? onDismiss;

  const ConfigurationPanel({
    super.key,
    required this.configuration,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ListenableBuilder(
        listenable: configuration,
        builder: (context, child) {
          final viewConfig = configuration.viewConfiguration;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 20, color: Color(0xFF48A9A6)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cấu hình',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE3E3E3),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (onDismiss != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                        onPressed: onDismiss,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (viewConfig is MultiDayViewConfiguration) ...[
                        _buildWeekConfig(context, viewConfig),
                        const SizedBox(height: 8),
                        _buildHeaderConfig(context),
                        const SizedBox(height: 8),
                        _buildBodyConfig(context),
                      ] else if (viewConfig is MonthViewConfiguration) ...[
                        _buildMonthConfig(context, viewConfig),
                      ] else if (viewConfig is ScheduleViewConfiguration) ...[
                        _buildScheduleConfig(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeekConfig(BuildContext context, MultiDayViewConfiguration viewConfig) {
    return ExpansionTile(
      title: const Text('Cấu hình tuần/ngày', style: TextStyle(color: Color(0xFFE3E3E3), fontWeight: FontWeight.bold, fontSize: 14)),
      initiallyExpanded: true,
      textColor: const Color(0xFF48A9A6),
      iconColor: const Color(0xFF48A9A6),
      collapsedIconColor: Colors.white70,
      childrenPadding: const EdgeInsets.all(8),
      children: [
        _buildDropdown<int>(
          label: 'Ngày bắt đầu tuần',
          value: viewConfig.firstDayOfWeek,
          items: const [1, 2, 3, 4, 5, 6, 7],
          itemToString: (v) {
            switch (v) {
              case 1: return 'Thứ Hai';
              case 2: return 'Thứ Ba';
              case 3: return 'Thứ Tư';
              case 4: return 'Thứ Năm';
              case 5: return 'Thứ Sáu';
              case 6: return 'Thứ Bảy';
              case 7: return 'Chủ Nhật';
              default: return '';
            }
          },
          onChanged: (val) {
            configuration.viewConfiguration = viewConfig.copyWith(firstDayOfWeek: val);
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<TimeOfDay>(
                label: 'Bắt đầu',
                value: viewConfig.timeOfDayRange.start,
                items: List.generate(
                  viewConfig.timeOfDayRange.end.hour,
                  (index) => TimeOfDay(hour: index, minute: 0),
                ),
                itemToString: (v) => '${v.hour}:00',
                onChanged: (val) {
                  configuration.viewConfiguration = viewConfig.copyWith(
                    timeOfDayRange: TimeOfDayRange(start: val, end: viewConfig.timeOfDayRange.end),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown<TimeOfDay>(
                label: 'Kết thúc',
                value: viewConfig.timeOfDayRange.end,
                items: List.generate(
                  24 - viewConfig.timeOfDayRange.start.hour,
                  (index) {
                    var value = index + viewConfig.timeOfDayRange.start.hour + 1;
                    var minute = 0;
                    if (value > 23) {
                      value = 23;
                      minute = 59;
                    }
                    return TimeOfDay(hour: value, minute: minute);
                  },
                ),
                itemToString: (v) => v.hour == 23 && v.minute == 59 ? '23:59' : '${v.hour}:00',
                onChanged: (val) {
                  configuration.viewConfiguration = viewConfig.copyWith(
                    timeOfDayRange: TimeOfDayRange(start: viewConfig.timeOfDayRange.start, end: val),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderConfig(BuildContext context) {
    final headerConfig = configuration.multiDayHeaderConfiguration;
    return ExpansionTile(
      title: const Text('Cấu hình Header', style: TextStyle(color: Color(0xFFE3E3E3), fontWeight: FontWeight.bold, fontSize: 14)),
      initiallyExpanded: true,
      textColor: const Color(0xFF48A9A6),
      iconColor: const Color(0xFF48A9A6),
      collapsedIconColor: Colors.white70,
      childrenPadding: const EdgeInsets.all(8),
      children: [
        SwitchListTile(
          title: const Text('Hiển thị Header', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
          value: configuration.showHeader,
          activeColor: const Color(0xFF48A9A6),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => configuration.showHeader = val,
        ),
        SwitchListTile(
          title: const Text('Hiển thị thẻ', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
          value: headerConfig.showTiles,
          activeColor: const Color(0xFF48A9A6),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            configuration.multiDayHeaderConfiguration = headerConfig.copyWith(showTiles: val);
          },
        ),
        _buildDropdown<double>(
          label: 'Chiều cao ô',
          value: headerConfig.tileHeight,
          items: const [24.0, 32.0, 40.0, 48.0],
          itemToString: (v) => '${v.toInt()} px',
          onChanged: (val) {
            configuration.multiDayHeaderConfiguration = headerConfig.copyWith(tileHeight: val);
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown<int>(
          label: 'Số lượng sự kiện dọc tối đa',
          value: headerConfig.maximumNumberOfVerticalEvents ?? 0,
          items: const [0, 1, 2, 3, 4, 5],
          itemToString: (v) => v == 0 ? 'Vô hạn' : '$v',
          onChanged: (val) {
            if (val == 0) {
              configuration.multiDayHeaderConfiguration = MultiDayHeaderConfiguration(
                showTiles: headerConfig.showTiles,
                tileHeight: headerConfig.tileHeight,
              );
            } else {
              configuration.multiDayHeaderConfiguration = headerConfig.copyWith(maximumNumberOfVerticalEvents: val);
            }
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown<EdgeInsets>(
          label: 'Lề sự kiện (LRTB)',
          value: headerConfig.eventPadding,
          items: const [
            EdgeInsets.only(left: 0, right: 4, top: 0, bottom: 2),
            EdgeInsets.only(left: 0, right: 8, top: 0, bottom: 2),
            EdgeInsets.only(left: 0, right: 12, top: 0, bottom: 2),
            EdgeInsets.only(left: 4, right: 0, top: 0, bottom: 2),
            EdgeInsets.only(left: 8, right: 0, top: 0, bottom: 2),
            EdgeInsets.only(left: 12, right: 0, top: 0, bottom: 2),
          ],
          itemToString: (v) => 'L: ${v.left.toInt()}, R: ${v.right.toInt()}, T: ${v.top.toInt()}, B: ${v.bottom.toInt()}',
          onChanged: (val) {
            configuration.multiDayHeaderConfiguration = headerConfig.copyWith(eventPadding: val);
          },
        ),
      ],
    );
  }

  Widget _buildBodyConfig(BuildContext context) {
    final bodyConfig = configuration.multiDayBodyConfiguration;
    final snapping = configuration.snapping;
    final interaction = configuration.interactionBody;
    return ExpansionTile(
      title: const Text('Cấu hình Thân lịch', style: TextStyle(color: Color(0xFFE3E3E3), fontWeight: FontWeight.bold, fontSize: 14)),
      initiallyExpanded: true,
      textColor: const Color(0xFF48A9A6),
      iconColor: const Color(0xFF48A9A6),
      collapsedIconColor: Colors.white70,
      childrenPadding: const EdgeInsets.all(8),
      children: [
        SwitchListTile(
          title: const Text('Hiển thị sự kiện nhiều ngày', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
          value: bodyConfig.showMultiDayEvents,
          activeColor: const Color(0xFF48A9A6),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            configuration.multiDayBodyConfiguration = bodyConfig.copyWith(showMultiDayEvents: val);
          },
        ),
        _buildDropdown<bool>(
          label: 'Bố cục ô',
          value: bodyConfig.eventLayoutStrategy == sideBySideLayoutStrategy,
          items: const [true, false],
          itemToString: (v) => v ? 'Song song' : 'Đè nhau',
          onChanged: (val) {
            configuration.multiDayBodyConfiguration = bodyConfig.copyWith(
              eventLayoutStrategy: val ? sideBySideLayoutStrategy : overlapLayoutStrategy,
            );
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown<EdgeInsets>(
          label: 'Lề sự kiện (LR)',
          value: bodyConfig.horizontalPadding,
          items: const [
            EdgeInsets.only(left: 0, right: 4, top: 0, bottom: 0),
            EdgeInsets.only(left: 0, right: 8, top: 0, bottom: 0),
            EdgeInsets.only(left: 0, right: 12, top: 0, bottom: 0),
            EdgeInsets.only(left: 4, right: 0, top: 0, bottom: 0),
            EdgeInsets.only(left: 8, right: 0, top: 0, bottom: 0),
            EdgeInsets.only(left: 12, right: 0, top: 0, bottom: 0),
          ],
          itemToString: (v) => 'L: ${v.left.toInt()}, R: ${v.right.toInt()}',
          onChanged: (val) {
            configuration.multiDayBodyConfiguration = bodyConfig.copyWith(horizontalPadding: val);
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown<double?>(
          label: 'Chiều cao ô tối thiểu',
          value: bodyConfig.minimumTileHeight,
          items: const [null, 24.0, 32.0, 40.0, 48.0],
          itemToString: (v) => v == null ? 'Không' : '${v.toInt()} px',
          onChanged: (val) {
            configuration.multiDayBodyConfiguration = MultiDayBodyConfiguration(
              minimumTileHeight: val,
              showMultiDayEvents: bodyConfig.showMultiDayEvents,
              horizontalPadding: bodyConfig.horizontalPadding,
            );
          },
        ),
        const Divider(color: Colors.white10, height: 16),
        ValueListenableBuilder<CalendarSnapping>(
          valueListenable: snapping,
          builder: (context, snapVal, _) {
            return Column(
              children: [
                SwitchListTile(
                  title: const Text('Hít vào sự kiện khác', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: snapVal.snapToOtherEvents,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    snapping.value = snapVal.copyWith(snapToOtherEvents: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Hít vào chỉ báo thời gian', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: snapVal.snapToTimeIndicator,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    snapping.value = snapVal.copyWith(snapToTimeIndicator: val);
                  },
                ),
                _buildDropdown<int>(
                  label: 'Khoảng hít (phút)',
                  value: snapVal.snapIntervalMinutes,
                  items: const [1, 5, 10, 30],
                  itemToString: (v) => '$v phút',
                  onChanged: (val) {
                    snapping.value = snapVal.copyWith(snapIntervalMinutes: val);
                  },
                ),
                const SizedBox(height: 8),
                _buildDropdown<int>(
                  label: 'Phạm vi hít',
                  value: snapVal.snapRange.inMinutes,
                  items: const [1, 5, 10, 15, 30],
                  itemToString: (v) => '$v phút',
                  onChanged: (val) {
                    snapping.value = snapVal.copyWith(snapRange: Duration(minutes: val));
                  },
                ),
              ],
            );
          },
        ),
        const Divider(color: Colors.white10, height: 16),
        ValueListenableBuilder<CalendarInteraction>(
          valueListenable: interaction,
          builder: (context, interactVal, _) {
            return Column(
              children: [
                SwitchListTile(
                  title: const Text('Cho phép đổi kích thước', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowResizing,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowResizing: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cho phép đổi lịch', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowRescheduling,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowRescheduling: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cho phép tạo sự kiện', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowEventCreation,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowEventCreation: val);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMonthConfig(BuildContext context, MonthViewConfiguration viewConfig) {
    final monthConfig = configuration.monthBodyConfiguration;
    final interaction = configuration.interactionBody;
    return ExpansionTile(
      title: const Text('Cấu hình Tháng', style: TextStyle(color: Color(0xFFE3E3E3), fontWeight: FontWeight.bold, fontSize: 14)),
      initiallyExpanded: true,
      textColor: const Color(0xFF48A9A6),
      iconColor: const Color(0xFF48A9A6),
      collapsedIconColor: Colors.white70,
      childrenPadding: const EdgeInsets.all(8),
      children: [
        _buildDropdown<int>(
          label: 'Ngày bắt đầu tuần',
          value: viewConfig.firstDayOfWeek,
          items: const [1, 2, 3, 4, 5, 6, 7],
          itemToString: (v) {
            switch (v) {
              case 1: return 'Thứ Hai';
              case 2: return 'Thứ Ba';
              case 3: return 'Thứ Tư';
              case 4: return 'Thứ Năm';
              case 5: return 'Thứ Sáu';
              case 6: return 'Thứ Bảy';
              case 7: return 'Chủ Nhật';
              default: return '';
            }
          },
          onChanged: (val) {
            configuration.viewConfiguration = viewConfig.copyWith(firstDayOfWeek: val);
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown<double>(
          label: 'Chiều cao ô',
          value: monthConfig.tileHeight,
          items: const [24.0, 32.0, 40.0, 48.0],
          itemToString: (v) => '${v.toInt()} px',
          onChanged: (val) {
            configuration.monthBodyConfiguration = monthConfig.copyWith(tileHeight: val);
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown<EdgeInsets>(
          label: 'Lề sự kiện (LRTB)',
          value: monthConfig.eventPadding,
          items: const [
            EdgeInsets.only(left: 0, right: 4, top: 0, bottom: 2),
            EdgeInsets.only(left: 0, right: 8, top: 0, bottom: 2),
            EdgeInsets.only(left: 0, right: 12, top: 0, bottom: 2),
            EdgeInsets.only(left: 4, right: 0, top: 0, bottom: 2),
            EdgeInsets.only(left: 8, right: 0, top: 0, bottom: 2),
            EdgeInsets.only(left: 12, right: 0, top: 0, bottom: 2),
          ],
          itemToString: (v) => 'L: ${v.left.toInt()}, R: ${v.right.toInt()}, T: ${v.top.toInt()}, B: ${v.bottom.toInt()}',
          onChanged: (val) {
            configuration.monthBodyConfiguration = monthConfig.copyWith(eventPadding: val);
          },
        ),
        const Divider(color: Colors.white10, height: 16),
        ValueListenableBuilder<CalendarInteraction>(
          valueListenable: interaction,
          builder: (context, interactVal, _) {
            return Column(
              children: [
                SwitchListTile(
                  title: const Text('Cho phép đổi kích thước', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowResizing,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowResizing: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cho phép đổi lịch', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowRescheduling,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowRescheduling: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cho phép tạo sự kiện', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowEventCreation,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowEventCreation: val);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleConfig(BuildContext context) {
    final scheduleConfig = configuration.scheduleBodyConfiguration;
    final interaction = configuration.interactionBody;
    return ExpansionTile(
      title: const Text('Cấu hình Lịch trình', style: TextStyle(color: Color(0xFFE3E3E3), fontWeight: FontWeight.bold, fontSize: 14)),
      initiallyExpanded: true,
      textColor: const Color(0xFF48A9A6),
      iconColor: const Color(0xFF48A9A6),
      collapsedIconColor: Colors.white70,
      childrenPadding: const EdgeInsets.all(8),
      children: [
        _buildDropdown<EmptyDayBehavior>(
          label: 'Hành vi ngày trống',
          value: scheduleConfig.emptyDay,
          items: EmptyDayBehavior.values,
          itemToString: (v) {
            switch (v) {
              case EmptyDayBehavior.show: return 'Hiển thị';
              case EmptyDayBehavior.showToday: return 'Hiển thị hôm nay';
              case EmptyDayBehavior.hide: return 'Ẩn';
            }
          },
          onChanged: (val) {
            configuration.scheduleBodyConfiguration = scheduleConfig.copyWith(emptyDay: val);
          },
        ),
        const Divider(color: Colors.white10, height: 16),
        ValueListenableBuilder<CalendarInteraction>(
          valueListenable: interaction,
          builder: (context, interactVal, _) {
            return Column(
              children: [
                SwitchListTile(
                  title: const Text('Cho phép đổi kích thước', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowResizing,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowResizing: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cho phép đổi lịch', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowRescheduling,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowRescheduling: val);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cho phép tạo sự kiện', style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 13)),
                  value: interactVal.allowEventCreation,
                  activeColor: const Color(0xFF48A9A6),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    interaction.value = interactVal.copyWith(allowEventCreation: val);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemToString,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF131314),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1F22),
              style: const TextStyle(color: Color(0xFFE3E3E3), fontSize: 13),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemToString(item)),
                );
              }).toList(),
              onChanged: (T? val) {
                if (val != null) {
                  onChanged(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ZoomDetector & related widgets copied from the official web demo.
// ---------------------------------------------------------------------------

class ZoomDetector extends StatelessWidget {
  final Widget child;
  final CalendarController controller;
  const ZoomDetector({super.key, required this.child, required this.controller});

  @override
  Widget build(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return MobileZoomDetector(controller: controller, child: child);
      default:
        return DesktopZoomDetector(controller: controller, child: child);
    }
  }
}

mixin ZoomUtils {
  CalendarController get controller;
  ViewController? get viewController => controller.viewController;

  final minimumZoomLevel = 0.5;
  final maximumZoomLevel = 2.0;
  final scrollSensitivity = 0.1;

  MultiDayViewController? get multiDayViewController {
    if (viewController is MultiDayViewController) {
      return viewController as MultiDayViewController;
    } else {
      return null;
    }
  }

  ScrollController? get scrollController => multiDayViewController?.scrollController;
  ValueNotifier<double>? get heightPerMinute => multiDayViewController?.heightPerMinute;
  final ValueNotifier<bool> lock = ValueNotifier(false);
  double yOffset = 0;

  double scaleTrackpad(PointerPanZoomUpdateEvent event, double height) {
    return height * pow(2, log(event.scale) / 12);
  }

  double scale(PointerScaleEvent event, double height) {
    final newHeight = height * pow(2, log(event.scale) / 4);
    return newHeight.clamp(minimumZoomLevel, maximumZoomLevel);
  }

  double scroll(PointerScrollEvent event, double height) {
    return height + event.scrollDelta.dy.sign * -1 * scrollSensitivity;
  }

  void update(double height, double newHeight) {
    final clamped = newHeight.clamp(minimumZoomLevel, maximumZoomLevel);

    final zoomRatio = clamped / height;
    final scrollPosition = scrollController?.position.pixels;
    if (scrollPosition == null) return;

    final pointerPosition = scrollPosition + yOffset;
    final newPosition = (pointerPosition * zoomRatio) - yOffset;
    scrollController?.jumpTo(newPosition);
    heightPerMinute?.value = clamped;
  }

  bool keyHandler(KeyEvent event) {
    lock.value = HardwareKeyboard.instance.isControlPressed;
    return false;
  }

  ScrollBehavior scrollBehavior(bool lock) {
    return (lock ? const ScrollBehaviorNever() : const MaterialScrollBehavior()).copyWith(scrollbars: false);
  }
}

class DesktopZoomDetector extends StatefulWidget {
  final Widget child;
  final CalendarController controller;
  const DesktopZoomDetector({super.key, required this.child, required this.controller});

  @override
  State<DesktopZoomDetector> createState() => _DesktopZoomDetectorState();
}

class _DesktopZoomDetectorState extends State<DesktopZoomDetector> with ZoomUtils {
  @override
  CalendarController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(keyHandler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(keyHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (event) => yOffset = event.localPosition.dy,
      onPointerSignal: (event) {
        if (!HardwareKeyboard.instance.isControlPressed) return;

        final height = heightPerMinute?.value;
        if (height == null) return;

        double newHeight;
        if (event is PointerScaleEvent) {
          newHeight = scale(event, height);
        } else if (event is PointerScrollEvent) {
          newHeight = scroll(event, height);
        } else {
          return;
        }

        update(height, newHeight);
      },
      onPointerPanZoomStart: (_) => lock.value = true,
      onPointerPanZoomUpdate: (event) {
        if (lock.value == false) return;
        final height = heightPerMinute?.value;
        if (height == null) return;
        final newHeight = scaleTrackpad(event, height);
        update(height, newHeight);
      },
      behavior: HitTestBehavior.translucent,
      onPointerPanZoomEnd: (_) => lock.value = false,
      child: ValueListenableBuilder(
        valueListenable: lock,
        builder: (context, value, _) => ScrollConfiguration(behavior: scrollBehavior(value), child: widget.child),
      ),
    );
  }
}

class MobileZoomDetector extends StatefulWidget {
  final Widget child;
  final CalendarController controller;
  const MobileZoomDetector({super.key, required this.child, required this.controller});

  @override
  State<MobileZoomDetector> createState() => _MobileZoomDetectorState();
}

class _MobileZoomDetectorState extends State<MobileZoomDetector> with ZoomUtils {
  @override
  CalendarController get controller => widget.controller;

  double _previousScale = 0.0;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        AllowMultipleGestureRecognizer: GestureRecognizerFactoryWithHandlers<AllowMultipleGestureRecognizer>(
          AllowMultipleGestureRecognizer.new,
          (instance) {
            instance.onStart = (details) {
              yOffset = details.localFocalPoint.dy;
              _previousScale = 0;
              if (details.pointerCount <= 1) return;
            };
            instance.onUpdate = (details) {
              if (details.pointerCount <= 1) return;
              final height = heightPerMinute?.value;
              if (height == null) return;
              final delta = -(_previousScale - log(details.verticalScale));
              _previousScale = log(details.verticalScale);
              final newHeight = height + delta;
              update(height, newHeight);
            };
          },
        ),
      },
      child: widget.child,
    );
  }
}

class ScrollBehaviorNever extends ScrollBehavior {
  const ScrollBehaviorNever();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const NeverScrollableScrollPhysics();
}

class AllowMultipleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) => acceptGesture(pointer);
}
