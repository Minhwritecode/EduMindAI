import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'pomodoro_popup.dart';
import 'my_learning_page.dart';
import 'schedule_analyze_page.dart';
import 'learning_style_page.dart'; // QuizScreen
import 'state/notebook_context_state.dart';
import 'services/schedule_service.dart' as svc;
import 'services/notebook_mongo_sync.dart' as nb_sync;
import 'services/user_data_sync.dart';
import 'notebook_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'PMDEduMind Dashboard';
      case 1:
        return 'My Learning';
      case 2:
        return 'Thời Khóa Biểu';
      default:
        return 'PMDEduMind';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        elevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Color(0xFFE3E3E3),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE3E3E3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white10, height: 1.0),
        ),
      ),
      drawer: _buildDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: const [
          DashboardView(),
          MyLearningPage(),
          ScheduleAnalyzePage(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const PomodoroPopup(),
                );
              },
              backgroundColor: const Color(0xFF48A9A6),
              icon: const Icon(Icons.timer, color: Colors.white),
              label: const Text(
                'Pomodoro',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 1.0)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF1E1F22),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFF48A9A6),
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'My Learning',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'My schedule',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final nbState = context.watch<NotebookContextState>();
    return Drawer(
      backgroundColor: const Color(0xFF1E1F22),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF131314), Color(0xFF1C2D37)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundImage: AssetImage('assets/image.png'),
                ),
                const SizedBox(height: 10),
                Text(
                  nbState.userId.isNotEmpty ? nbState.userId : 'Tien Minh',
                  style: const TextStyle(
                    color: Color(0xFFE3E3E3),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined, color: Color(0xFFFF8C42)),
            title: const Text('Learning style (VARK)',
                style: TextStyle(color: Color(0xFFE3E3E3))),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const QuizScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Color(0xFF48A9A6)),
            title: const Text('Cài đặt',
                style: TextStyle(color: Color(0xFFE3E3E3))),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.question_answer_outlined, color: Colors.purpleAccent),
            title: const Text('Hỏi đáp (FAQ)',
                style: TextStyle(color: Color(0xFFE3E3E3))),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _isLoading = false;
  bool _loadingRecommendations = false;
  List<svc.TimetableDay> _timetable = [];
  List<svc.TodoTask> _todoList = [];
  List<nb_sync.Notebook> _notebooks = [];
  List<Map<String, dynamic>> _recommendations = [];

  final List<String> videoImageUrls = [
    'https://images.unsplash.com/photo-1607799279861-4dd421887fb3?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1579468118864-1b9ea3c0db4a?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1547658719-da2b51169166?auto=format&fit=crop&w=400&q=80',
  ];

  final List<String> _quotes = [
    "The secret of getting ahead is getting started.",
    "It always seems impossible until it's done.",
    "Don't watch the clock; do what it does. Keep going.",
    "Success is not final, failure is not fatal: it is the courage to continue that counts.",
    "Believe you can and you're halfway there.",
    "Study hard what interests you the most in the most undisciplined, irreverent and original manner possible.",
  ];
  late String _currentQuote;

  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  final TextEditingController _taskController = TextEditingController();
  String? _selectedNotebookForTask;
  XFile? _headerImage;

  Future<void> _pickHeaderImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _headerImage = image;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentQuote = _quotes[Random().nextInt(_quotes.length)];

    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadingRecommendations = true;
    });
    final userId = context.read<NotebookContextState>().userId;

    final (schedule, _) = await svc.ScheduleService.fetchSchedule(userId);
    if (schedule != null) {
      _timetable = schedule.timetable;
      _todoList = schedule.todoList;
    }

    final (notebooks, _) =
        await nb_sync.NotebookMongoSync.fetchNotebooks(userId);
    if (notebooks != null) {
      _notebooks = notebooks;
    }

    final (recs, _) = await UserDataSync.fetchRecommendations(userId);
    if (recs != null) {
      _recommendations = recs;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadingRecommendations = false;
      });
    }
  }

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
    final (taskId, err) =
        await svc.ScheduleService.addOrUpdateTodo(userId, task);

    if (err == null && taskId != null) {
      _taskController.clear();
      _selectedNotebookForTask = null;
      await _loadData();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi thêm task: $err')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi xóa task: $err')));
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
    final nb = _notebooks.firstWhere((n) => n.id == id,
        orElse: () => nb_sync.Notebook(id: id, title: 'Notebook', text: ''));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotebookDetailPage(notebook: nb)),
    ).then((_) => _loadData());
  }

  Future<void> _importNotebookFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
      );
      if (result == null) return;

      String text = '';
      if (kIsWeb) {
        if (result.files.single.bytes != null) {
          text = utf8.decode(result.files.single.bytes!);
        }
      } else {
        if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          text = await file.readAsString();
        } else if (result.files.single.bytes != null) {
          text = utf8.decode(result.files.single.bytes!);
        }
      }

      if (text.isNotEmpty) {
        final title = result.files.single.name.replaceAll('.txt', '').replaceAll('.md', '');
        final userId = context.read<NotebookContextState>().userId;
        
        setState(() => _isLoading = true);
        final (_, err) = await nb_sync.NotebookMongoSync.saveNotebook(
          userId: userId,
          id: '',
          title: title,
          description: 'Imported from ${result.files.single.name}',
          text: text,
        );
        
        await _loadData();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err ?? 'Đã nạp nội dung tài liệu "$title" thành công!',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi nạp file: $e')),
      );
    }
  }

  String _getCourseThumbnail(String title, String category, int index) {
    final cat = category.toLowerCase();
    if (cat.contains('c++') || cat.contains('cpp') || cat.contains('dsa')) {
      return 'https://images.unsplash.com/photo-1607799279861-4dd421887fb3?auto=format&fit=crop&w=400&q=80';
    } else if (cat.contains('python')) {
      return 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=400&q=80';
    } else if (cat.contains('javascript') || cat.contains('js')) {
      return 'https://images.unsplash.com/photo-1579468118864-1b9ea3c0db4a?auto=format&fit=crop&w=400&q=80';
    } else if (cat.contains('web')) {
      return 'https://images.unsplash.com/photo-1547658719-da2b51169166?auto=format&fit=crop&w=400&q=80';
    }
    return videoImageUrls[index % videoImageUrls.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF48A9A6)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          // Desktop: Fixed height layout
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildLeftColumn(isFixed: true)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildRightColumn(isFixed: true)),
              ],
            ),
          );
        } else {
          // Mobile: Scrollable layout
          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildLeftColumn(isFixed: false),
                  const SizedBox(height: 16),
                  _buildRightColumn(isFixed: false),
                  const SizedBox(height: 80), // padding for FAB
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildLeftColumn({required bool isFixed}) {
    final children = [
      _buildTopHeaderRow(isFixed: isFixed),
      const SizedBox(height: 16),
      _buildQuotesBlock(),
      const SizedBox(height: 16),
      if (isFixed)
        Expanded(child: _buildRecommendedCourseBlock())
      else
        _buildRecommendedCourseBlock(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildRightColumn({required bool isFixed}) {
    final children = [
      if (isFixed)
        Expanded(flex: 2, child: _buildTimetableBlock(isFixed: isFixed))
      else
        _buildTimetableBlock(isFixed: isFixed),
      const SizedBox(height: 16),
      if (isFixed)
        Expanded(flex: 3, child: _buildTodoListBlock(isFixed: isFixed))
      else
        _buildTodoListBlock(isFixed: isFixed),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildTopHeaderRow({required bool isFixed}) {
    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: Time & Latest Notebooks
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF131314), Color(0xFF1D263B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF48A9A6).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('hh:mm a').format(_currentTime),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE3E3E3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMMM d').format(_currentTime),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Latest Notebooks",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE3E3E3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: _notebooks.isEmpty
                          ? const Center(
                              child: Text(
                                "No notebooks yet.",
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: min(3, _notebooks.length),
                              itemBuilder: (context, index) {
                                final nb = _notebooks[index];
                                return Container(
                                  width: 140,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Material(
                                    color: const Color(0xFF48A9A6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _openNotebookById(nb.id),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Center(
                                          child: Text(
                                            nb.title,
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF48A9A6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Column: Image Placeholder
              Expanded(
                flex: 2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickHeaderImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131314),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _headerImage != null
                          ? Image.network(
                              _headerImage!.path,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.white38,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Add Picture",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C42).withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: cardContent,
      ),
    );
  }

  Widget _buildQuotesBlock() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131314), Color(0xFF1E272C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF48A9A6).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF48A9A6).withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            const Icon(Icons.format_quote, color: Color(0xFF48A9A6), size: 32),
            const SizedBox(height: 12),
            Text(
              _currentQuote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Color(0xFFE3E3E3),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCourseBlock() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B5DE5).withOpacity(0.03), // Subtle purple personalization glow
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommended Courses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE3E3E3),
                  ),
                ),
                if (_loadingRecommendations)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF48A9A6)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF48A9A6), size: 20),
                    onPressed: _loadData,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _recommendations.isEmpty
                  ? const Center(
                      child: Text(
                        "Không có đề xuất nào.\nHãy làm Quiz VARK để nhận gợi ý khóa học thích hợp!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recommendations.length,
                      itemBuilder: (context, index) {
                        final rec = _recommendations[index];
                        final title = rec['title'] ?? rec['course_name'] ?? 'Khóa học';
                        final category = rec['category'] ?? 'General';
                        final difficulty = rec['difficulty'] ?? 'Medium';
                        final rating = rec['rating']?.toString() ?? '4.5';
                        final imageUrl = _getCourseThumbnail(title, category, index);

                        Color diffColor = Colors.green;
                        if (difficulty.toLowerCase() == 'hard') {
                          diffColor = Colors.redAccent;
                        } else if (difficulty.toLowerCase() == 'medium') {
                          diffColor = Colors.orangeAccent;
                        }

                        return Container(
                          width: 220,
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131314),
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(11),
                                ),
                                child: Image.network(
                                  imageUrl,
                                  height: 95,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 95,
                                    color: const Color(0xFF1C2D37),
                                    child: const Center(
                                      child: Icon(Icons.school, color: Color(0xFF48A9A6)),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE3E3E3),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: diffColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              difficulty,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: diffColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, size: 12, color: Colors.amber),
                                              const SizedBox(width: 2),
                                              Text(
                                                rating,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableBlock({required bool isFixed}) {
    final today = DateFormat('EEEE').format(DateTime.now());
    final dayData = _timetable.firstWhere((d) => d.dayOfWeek == today,
        orElse: () => svc.TimetableDay(dayOfWeek: today, slots: []));
    final slots = dayData.slots;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Timetable (Today)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE3E3E3),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                "View All",
                style: TextStyle(color: Color(0xFF48A9A6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "No classes today! Relax.",
                style: TextStyle(color: Colors.white38),
              ),
            ),
          )
        else
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final slot = slots[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131314),
                    border: Border.all(
                      color: const Color(0xFF48A9A6).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48A9A6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slot.startTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFE3E3E3),
                              ),
                            ),
                            if (slot.roomOrLink.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                slot.roomOrLink,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF48A9A6).withOpacity(0.03),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isFixed ? content : SizedBox(height: 300, child: content),
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1F22),
              title: const Text('Thêm Nhiệm Vụ',
                  style: TextStyle(color: Color(0xFFE3E3E3))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _taskController,
                    style: const TextStyle(color: Color(0xFFE3E3E3)),
                    decoration: const InputDecoration(
                      hintText: 'Nhập nhiệm vụ mới...',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF48A9A6))),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1F22),
                    hint: const Text('Liên kết Notebook (Tùy chọn)',
                        style: TextStyle(fontSize: 12, color: Colors.white60)),
                    value: _selectedNotebookForTask,
                    items: _notebooks
                        .map((nb) => DropdownMenuItem(
                            value: nb.id,
                            child: Text(nb.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFFE3E3E3)))))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => _selectedNotebookForTask = v),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Nạp file .txt, .md',
                  icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF48A9A6)),
                  onPressed: () {
                    Navigator.pop(context);
                    _importNotebookFromFile();
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF48A9A6)),
                  onPressed: () async {
                    if (_taskController.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    await _addTask();
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

  Widget _buildTodoListBlock({required bool isFixed}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('To Do List',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE3E3E3))),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF48A9A6)),
              onPressed: _showAddTaskDialog,
            ),
          ],
        ),
        const SizedBox(height: 4),
        _todoList.isEmpty
            ? const Expanded(
                flex: 1,
                child: Center(
                    child: Text('Không có nhiệm vụ nào! Thư giãn thôi.',
                        style: TextStyle(color: Colors.white38))),
              )
            : Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: _todoList.length,
                  itemBuilder: (context, index) {
                    final task = _todoList[index];
                    final isLinked = task.notebookId.isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? const Color(0xFF131314).withOpacity(0.5)
                            : const Color(0xFF131314),
                        border: Border.all(color: Colors.white10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: Checkbox(
                          value: task.isCompleted,
                          activeColor: const Color(0xFF48A9A6),
                          checkColor: Colors.white,
                          onChanged: (_) => _toggleTaskCompletion(task),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? Colors.white38
                                : const Color(0xFFE3E3E3),
                            fontSize: 14,
                          ),
                        ),
                        subtitle: isLinked
                            ? GestureDetector(
                                onTap: () => _openNotebookById(task.notebookId),
                                child: const Text(
                                  '🔗 Xem tài liệu liên kết',
                                  style: TextStyle(
                                      color: Color(0xFF48A9A6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _deleteTask(task.taskId),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C42).withOpacity(0.02),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isFixed ? content : SizedBox(height: 400, child: content),
      ),
    );
  }
}
