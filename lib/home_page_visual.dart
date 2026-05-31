import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'focus_mode_page.dart';
import 'my_learning_page.dart';
import 'schedule_analyze_page.dart';
import 'state/notebook_context_state.dart';
import 'services/schedule_service.dart' as svc;
import 'services/notebook_mongo_sync.dart' as nb_sync;
import 'notebook_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedPreference;
  int _selectedIndex = 0;
  bool _isLoading = false;

  List<svc.TimetableDay> _timetable = [];
  List<svc.TodoTask> _todoList = [];
  List<nb_sync.Notebook> _notebooks = [];

  // Example data placeholders for recommended videos
  final List<String> videoTitles = [
    'C++ Basics in One Shot - Strivers A2Z DSA Course - L1',
    'Introduction to JavaScript + Setup | JavaScript Tutorial in Hindi #1',
    'Python Tutorial for Beginners | Learn Python in 1.5 Hours',
    'ApnaCollegeOfficial which Coding Platform should I study from?',
    'Web Development Tutorial for Beginners (2024 Edition)',
  ];

  final List<String> videoImageUrls = [
    'https://th.bing.com/th/id/OIP.0STrpvtmnpiN8MxYI-xUPwAAAA?rs=1&pid=ImgDetMain',
    'https://www.codewithharry.com/_next/image/?url=https:%2F%2Fcwh-full-next-space.fra1.digitaloceanspaces.com%2Fvideoseries%2Fultimate-js-tutorial-hindi-1%2FJS-Thumb.jpg&w=828&q=75',
    'https://th.bing.com/th/id/OIP.raiOFsxSpMFzOFwa2TXUmQAAAA?rs=1&pid=ImgDetMain',
    'https://i.ytimg.com/vi/qTph1pj_rCo/maxresdefault.jpg',
    'https://www.someurl.com/your-image4.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = context.read<NotebookContextState>().userId;
    
    // 1. Fetch Schedules
    final (schedule, _) = await svc.ScheduleService.fetchSchedule(userId);
    if (schedule != null) {
      _timetable = schedule.timetable;
      _todoList = schedule.todoList;
    }

    // 2. Fetch Notebooks to allow linking
    final (notebooks, _) = await nb_sync.NotebookMongoSync.fetchNotebooks(userId);
    if (notebooks != null) {
      _notebooks = notebooks;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyLearningPage()),
        ).then((_) => _loadData());
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleAnalyzePage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FocusModePage()),
        );
        break;
    }
  }

  final TextEditingController _taskController = TextEditingController();
  String? _selectedNotebookForTask;

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    final userId = context.read<NotebookContextState>().userId;
    final task = svc.TodoTask(
      taskId: '',
      title: title,
      isCompleted: false,
      notebookId: _selectedNotebookForTask ?? '',
      dueDate: DateTime.now().add(const Duration(days: 2)).toIso8601String(),
    );

    setState(() => _isLoading = true);
    final (taskId, err) = await svc.ScheduleService.addOrUpdateTodo(userId, task);
    
    if (err == null && taskId != null) {
      _taskController.clear();
      _selectedNotebookForTask = null;
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi thêm task: $err')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final userId = context.read<NotebookContextState>().userId;
    setState(() => _isLoading = true);
    final err = await svc.ScheduleService.deleteTodo(userId, taskId);
    if (err == null) {
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa task: $err')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTaskCompletion(svc.TodoTask task) async {
    final userId = context.read<NotebookContextState>().userId;
    final updated = svc.TodoTask(
      taskId: task.taskId,
      title: task.title,
      dueDate: task.dueDate,
      isCompleted: !task.isCompleted,
      notebookId: task.notebookId,
    );
    setState(() => _isLoading = true);
    await svc.ScheduleService.addOrUpdateTodo(userId, updated);
    await _loadData();
  }

  void _openNotebookById(String id) {
    final nb = _notebooks.firstWhere((n) => n.id == id, orElse: () => nb_sync.Notebook(id: id, title: 'Notebook', text: ''));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotebookDetailPage(notebook: nb)),
    ).then((_) => _loadData());
  }

  void _addTimetableSlotDialog() {
    final subjectCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '08:00');
    final endCtrl = TextEditingController(text: '09:30');
    final roomCtrl = TextEditingController();
    String selectedDay = 'Monday';
    String? selectedNotebook;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm Lịch Học Tập'),
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
                        Expanded(child: TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Bắt đầu (HH:MM)'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'Kết thúc (HH:MM)'))),
                      ],
                    ),
                    TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Phòng học / Link Zoom')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedNotebook,
                      decoration: const InputDecoration(labelText: 'Gắn với Notebook'),
                      items: _notebooks.map((nb) => DropdownMenuItem(value: nb.id, child: Text(nb.title))).toList(),
                      onChanged: (v) => setDialogState(() => selectedNotebook = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
                  onPressed: () async {
                    if (subjectCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);

                    final newSlot = svc.TimeSlot(
                      startTime: startCtrl.text.trim(),
                      endTime: endCtrl.text.trim(),
                      subject: subjectCtrl.text.trim(),
                      roomOrLink: roomCtrl.text.trim(),
                      notebookId: selectedNotebook ?? '',
                    );

                    // Update timetable local list
                    final dayIndex = _timetable.indexWhere((d) => d.dayOfWeek == selectedDay);
                    if (dayIndex >= 0) {
                      _timetable[dayIndex].slots.add(newSlot);
                    }

                    final userId = context.read<NotebookContextState>().userId;
                    setState(() => _isLoading = true);
                    final err = await svc.ScheduleService.updateTimetable(userId, _timetable);
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $err')));
                    }
                    await _loadData();
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF48A9A6),
        title: const Text('PMDEduMind', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF48A9A6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 40, backgroundImage: AssetImage('lib/assets/profile_icon.jpg')),
                  SizedBox(height: 10),
                  Text('Tien Minh', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(title: const Text('Cài đặt'), onTap: () {}),
            ListTile(title: const Text('Hỏi đáp (FAQ)'), onTap: () {}),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF48A9A6)))
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search & Preference Row
                    Row(
                      children: [
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm tài liệu...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          hint: const Text('Học tập', style: TextStyle(color: Color(0xFF48A9A6), fontWeight: FontWeight.bold)),
                          value: _selectedPreference,
                          items: ['Visual', 'Auditory', 'Reading/Writing', 'Kinesthetic']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedPreference = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Weekly Timetable Grid/Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lịch Học Của Bạn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131))),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF48A9A6), size: 28),
                          onPressed: _addTimetableSlotDialog,
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTimetableSection(),

                    const SizedBox(height: 24),
                    const Text('Gợi Ý Cho Bạn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131))),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: videoTitles.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 180,
                              child: Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: Image.network(videoImageUrls[index], width: 180, height: 100, fit: BoxFit.cover),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(videoTitles[index], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text('Nhiệm Vụ Cần Làm (To-Do)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131))),
                    const SizedBox(height: 12),
                    
                    // Task Input Field
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _taskController,
                              decoration: const InputDecoration(
                                hintText: 'Nhập nhiệm vụ mới...',
                                border: InputBorder.none,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                DropdownButton<String>(
                                  hint: const Text('Liên kết Notebook'),
                                  value: _selectedNotebookForTask,
                                  items: _notebooks.map((nb) => DropdownMenuItem(value: nb.id, child: Text(nb.title))).toList(),
                                  onChanged: (v) => setState(() => _selectedNotebookForTask = v),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
                                  onPressed: _addTask,
                                  child: const Text('Thêm Task'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Tasks List
                    _todoList.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('Không có nhiệm vụ nào! Thư giãn thôi.', style: TextStyle(color: Colors.grey))),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _todoList.length,
                          itemBuilder: (context, index) {
                            final task = _todoList[index];
                            final isLinked = task.notebookId.isNotEmpty;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Checkbox(
                                  value: task.isCompleted,
                                  activeColor: const Color(0xFF48A9A6),
                                  onChanged: (_) => _toggleTaskCompletion(task),
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                    color: task.isCompleted ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                subtitle: isLinked 
                                  ? GestureDetector(
                                      onTap: () => _openNotebookById(task.notebookId),
                                      child: const Text(
                                        '🔗 Xem tài liệu liên kết',
                                        style: TextStyle(color: Color(0xFF48A9A6), fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteTask(task.taskId),
                                ),
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
            ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF48A9A6),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'My Learning'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'My schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Pomodoro'),
        ],
      ),
    );
  }

  Widget _buildTimetableSection() {
    // Collect all slots across days
    List<Map<String, dynamic>> allSlots = [];
    for (var day in _timetable) {
      for (var slot in day.slots) {
        allSlots.add({
          'day': day.dayOfWeek,
          'slot': slot,
        });
      }
    }

    if (allSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Text('Lịch học của bạn đang trống! Nhấp vào nút + ở trên để thêm buổi học đầu tiên.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allSlots.length,
        itemBuilder: (context, index) {
          final day = allSlots[index]['day'] as String;
          final slot = allSlots[index]['slot'] as svc.TimeSlot;
          final isLinked = slot.notebookId.isNotEmpty;

          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF48A9A6).withOpacity(0.2))),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isLinked ? () => _openNotebookById(slot.notebookId) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF48A9A6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(day.substring(0, 3).toUpperCase(), style: const TextStyle(color: Color(0xFF48A9A6), fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                          const Spacer(),
                          Text('${slot.startTime}–${slot.endTime}', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(slot.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(slot.roomOrLink.isEmpty ? 'Không có phòng' : slot.roomOrLink, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      if (isLinked) ...[
                        const Spacer(),
                        const Text('🔗 Vào Notebook học tập', style: TextStyle(color: Color(0xFF48A9A6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
