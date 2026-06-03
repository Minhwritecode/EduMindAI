import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'services/notebook_mongo_sync.dart';
import 'services/chat_service.dart';
import 'state/notebook_context_state.dart';

class NotebookDetailPage extends StatefulWidget {
  final Notebook notebook;

  const NotebookDetailPage({super.key, required this.notebook});

  @override
  State<NotebookDetailPage> createState() => _NotebookDetailPageState();
}

class _NotebookDetailPageState extends State<NotebookDetailPage>
    with SingleTickerProviderStateMixin {
  late Notebook _notebook;
  late TextEditingController _sourceTitleController;
  late TextEditingController _sourceContentController;
  bool _isSaving = false;
  bool _isLoadingChat = false;

  // View state controllers
  late TabController _tabController;

  // Chat states
  List<ChatMessage> messages = [];
  final ChatUser currentUser = ChatUser(id: "user", firstName: "You");
  final ChatUser geminiUser = ChatUser(
    id: "ai",
    firstName: "AI Tutor",
    profileImage: "https://cdn-icons-png.flaticon.com/512/8649/8649595.png",
  );

  // Active study tool asset pointers
  MindmapItem? _selectedMindmap;
  QuizItem? _selectedQuiz;
  FlashcardDeck? _selectedFlashcardDeck;

  // Selected source content viewer
  SourceItem? _selectedSource;
  late TextEditingController _sourceViewerController;

  // Active quiz playing states
  int _currentQuizQuestionIndex = 0;
  String? _selectedQuizOption;
  bool _quizAnswered = false;
  int _quizScore = 0;

  // Active flashcard playing states
  int _currentFlashcardIndex = 0;
  bool _flashcardFlipped = false;

  final Color _bgColor = const Color(0xFF131314);
  final Color _panelColor = const Color(0xFF1E1F22);
  final Color _accentColor = const Color(0xFF48A9A6);
  final Color _textColor = const Color(0xFFE3E3E3);

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    _sourceTitleController = TextEditingController();
    _sourceContentController = TextEditingController();
    _sourceViewerController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);

    // Select first source as default if any
    if (_notebook.sources.isNotEmpty) {
      _selectedSource = _notebook.sources.first;
      _sourceViewerController.text = _selectedSource!.content;
    }

    _loadChatHistory();
  }

  @override
  void dispose() {
    _sourceTitleController.dispose();
    _sourceContentController.dispose();
    _sourceViewerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoadingChat = true);
    final (history, err) = await ChatService.fetchChatHistory(_notebook.id);
    if (history != null && err == null) {
      setState(() {
        messages = history
            .map((msg) => ChatMessage(
                  user: msg.sender == 'user' ? currentUser : geminiUser,
                  createdAt: msg.timestamp != null
                      ? DateTime.parse(msg.timestamp!)
                      : DateTime.now(),
                  text: msg.messageText,
                ))
            .toList()
            .reversed
            .toList(); // DashChat expects newest first
      });
    }
    setState(() => _isLoadingChat = false);
  }

  Future<void> _saveCurrentSource() async {
    if (_selectedSource == null) return;
    setState(() => _isSaving = true);
    final userId = context.read<NotebookContextState>().userId;

    // Create updated source list
    final updatedSources = _notebook.sources.map((s) {
      if (s.sourceId == _selectedSource!.sourceId) {
        return SourceItem(
          sourceId: s.sourceId,
          title: s.title,
          sourceType: s.sourceType,
          content: _sourceViewerController.text,
          fileUrl: s.fileUrl,
        );
      }
      return s;
    }).toList();

    final (id, err) = await NotebookMongoSync.saveNotebook(
      userId: userId,
      id: _notebook.id,
      title: _notebook.title,
      description: _notebook.description,
      text: _notebook.text,
      sources: updatedSources,
      mindmaps: _notebook.mindmaps,
      quizzes: _notebook.quizzes,
      flashcards: _notebook.flashcards,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (err == null) {
          _notebook = Notebook(
            id: id ?? _notebook.id,
            title: _notebook.title,
            description: _notebook.description,
            text: _notebook.text,
            sources: updatedSources,
            mindmaps: _notebook.mindmaps,
            quizzes: _notebook.quizzes,
            flashcards: _notebook.flashcards,
          );
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã lưu nguồn thành công!')));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $err')));
        }
      });
    }
  }

  Future<void> _addSourceDialog() async {
    String? pickedFileName;
    List<int>? pickedFileBytes;
    bool isUploadingFile = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                backgroundColor: _panelColor,
                title: Text('Thêm Nguồn Học Tập',
                    style: TextStyle(color: _textColor)),
                content: SizedBox(
                  width: 450,
                  height: 360,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: _accentColor,
                        labelColor: _accentColor,
                        unselectedLabelColor: Colors.white60,
                        tabs: const [
                          Tab(
                              icon: Icon(Icons.edit_note),
                              text: 'Nhập thủ công'),
                          Tab(
                              icon: Icon(Icons.upload_file),
                              text: 'Tải lên tệp'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Manual entry
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: _sourceTitleController,
                                  style: TextStyle(color: _textColor),
                                  decoration: const InputDecoration(
                                    labelText: 'Tiêu đề tài liệu',
                                    labelStyle:
                                        TextStyle(color: Colors.white60),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _sourceContentController,
                                    style: TextStyle(color: _textColor),
                                    maxLines: null,
                                    expands: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Nội dung văn bản...',
                                      labelStyle:
                                          TextStyle(color: Colors.white60),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Tab 2: File Picker
                            isUploadingFile
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                            color: _accentColor),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Đang tải lên & trích xuất văn bản...',
                                          style: TextStyle(
                                              color: _textColor, fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'AI đang phân tích các slide, bảng biểu và trang tài liệu',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11),
                                        )
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (pickedFileName == null) ...[
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: () async {
                                            try {
                                              final result =
                                                  await FilePicker.pickFiles(
                                                type: FileType.custom,
                                                allowedExtensions: [
                                                  'pdf',
                                                  'docx',
                                                  'pptx',
                                                  'txt'
                                                ],
                                                withData: true,
                                              );
                                              if (result != null &&
                                                  result.files.isNotEmpty) {
                                                final file = result.files.first;
                                                setDialogState(() {
                                                  pickedFileName = file.name;
                                                  pickedFileBytes = file.bytes;
                                                });
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Lỗi chọn file: $e')),
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.white24,
                                                  style: BorderStyle.solid),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              color: Colors.white
                                                  .withValues(alpha: 0.02),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                    Icons.cloud_upload_outlined,
                                                    size: 48,
                                                    color: _accentColor),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Chọn tài liệu từ thiết bị',
                                                  style: TextStyle(
                                                      color: _textColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14),
                                                ),
                                                const SizedBox(height: 6),
                                                const Text(
                                                  'Hỗ trợ PDF, Word (DOCX), PowerPoint (PPTX), TXT',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.04),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: _accentColor.withValues(
                                                    alpha: 0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                pickedFileName!.endsWith('.pdf')
                                                    ? Icons.picture_as_pdf
                                                    : pickedFileName!
                                                            .endsWith('.docx')
                                                        ? Icons.description
                                                        : pickedFileName!
                                                                .endsWith(
                                                                    '.pptx')
                                                            ? Icons.slideshow
                                                            : Icons.article,
                                                color: _accentColor,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      pickedFileName!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          color: _textColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${((pickedFileBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB',
                                                      style: const TextStyle(
                                                          color: Colors.white38,
                                                          fontSize: 10),
                                                    )
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.cancel,
                                                    color: Colors.grey),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    pickedFileName = null;
                                                    pickedFileBytes = null;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        )
                                      ]
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('Hủy', style: TextStyle(color: Colors.grey)),
                  ),
                  Builder(
                    builder: (btnCtx) => FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: _accentColor),
                      onPressed: isUploadingFile
                          ? null
                          : () async {
                              final tabIndex =
                                  DefaultTabController.of(btnCtx).index;
                              final userId =
                                  context.read<NotebookContextState>().userId;

                              if (_notebook.id.isEmpty) {
                                setDialogState(() {
                                  isUploadingFile = true;
                                });
                                final (newId, err) =
                                    await NotebookMongoSync.saveNotebook(
                                  userId: userId,
                                  id: '',
                                  title: _notebook.title,
                                  description: _notebook.description,
                                  text: _notebook.text,
                                  sources: _notebook.sources,
                                  mindmaps: _notebook.mindmaps,
                                  quizzes: _notebook.quizzes,
                                  flashcards: _notebook.flashcards,
                                );
                                if (err != null ||
                                    newId == null ||
                                    newId.isEmpty) {
                                  setDialogState(() {
                                    isUploadingFile = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Lỗi khởi tạo notebook: $err')),
                                  );
                                  return;
                                }
                                setState(() {
                                  _notebook = Notebook(
                                    id: newId,
                                    title: _notebook.title,
                                    description: _notebook.description,
                                    text: _notebook.text,
                                    sources: _notebook.sources,
                                    mindmaps: _notebook.mindmaps,
                                    quizzes: _notebook.quizzes,
                                    flashcards: _notebook.flashcards,
                                  );
                                });
                                setDialogState(() {
                                  isUploadingFile = false;
                                });
                              }

                              if (tabIndex == 0) {
                                // Manual text add
                                final title =
                                    _sourceTitleController.text.trim();
                                final content =
                                    _sourceContentController.text.trim();
                                if (title.isEmpty || content.isEmpty) return;
                                Navigator.pop(context);

                                setState(() => _isSaving = true);
                                final (sourceId, err) =
                                    await NotebookMongoSync.uploadSource(
                                  notebookId: _notebook.id,
                                  userId: userId,
                                  title: title,
                                  content: content,
                                );

                                _handleSourceUploadResult(
                                    sourceId, err, userId);
                              } else {
                                // File pick upload
                                if (pickedFileBytes == null ||
                                    pickedFileName == null) return;

                                setDialogState(() {
                                  isUploadingFile = true;
                                });

                                final (sourceId, err) =
                                    await NotebookMongoSync.uploadSourceFile(
                                  notebookId: _notebook.id,
                                  userId: userId,
                                  fileName: pickedFileName!,
                                  fileBytes: pickedFileBytes!,
                                );

                                setDialogState(() {
                                  isUploadingFile = false;
                                });

                                Navigator.pop(context);
                                _handleSourceUploadResult(
                                    sourceId, err, userId);
                              }
                            },
                      child: const Text('Thêm Nguồn'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleSourceUploadResult(
      String? sourceId, String? err, String userId) async {
    setState(() => _isSaving = true);
    if (err == null && sourceId != null) {
      // Reload notebook
      final (updatedNbs, _) = await NotebookMongoSync.fetchNotebooks(userId);
      if (updatedNbs != null) {
        final found = updatedNbs.firstWhere((n) => n.id == _notebook.id);
        setState(() {
          _notebook = found;
          _selectedSource =
              _notebook.sources.firstWhere((s) => s.sourceId == sourceId);
          _sourceViewerController.text = _selectedSource!.content;
        });
      }
      _sourceTitleController.clear();
      _sourceContentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã tải lên và trích xuất nguồn thành công!')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi upload: $err')));
    }
    setState(() => _isSaving = false);
  }

  Future<void> _sendMessage(ChatMessage chatMessage) async {
    setState(() {
      messages = [chatMessage, ...messages];
    });

    final userId = context.read<NotebookContextState>().userId;
    final (aiResponse, err) = await ChatService.sendChatMessage(
      notebookId: _notebook.id,
      userId: userId,
      messageText: chatMessage.text,
    );

    if (err == null && aiResponse != null) {
      setState(() {
        messages = [
          ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: aiResponse,
          ),
          ...messages
        ];
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI Error: $err')));
    }
  }

  Future<void> _generateAsset(String type) async {
    setState(() => _isSaving = true);
    final userId = context.read<NotebookContextState>().userId;

    if (type == 'mindmap') {
      final (mindmap, err) = await NotebookMongoSync.generateMindmap(
          _notebook.id, userId, 'Bản Đồ Tư Duy');
      if (err == null && mindmap != null) {
        setState(() {
          _selectedMindmap = mindmap;
          _notebook.mindmaps.add(mindmap);
          _tabController.animateTo(1);
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi Mindmap: $err')));
      }
    } else if (type == 'quiz') {
      final (quiz, err) = await NotebookMongoSync.generateQuiz(
          _notebook.id, userId, 'Bài Kiểm Tra');
      if (err == null && quiz != null) {
        setState(() {
          _selectedQuiz = quiz;
          _notebook.quizzes.add(quiz);
          _currentQuizQuestionIndex = 0;
          _selectedQuizOption = null;
          _quizAnswered = false;
          _quizScore = 0;
          _tabController.animateTo(2);
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi Quiz: $err')));
      }
    } else if (type == 'flashcards') {
      final (deck, err) = await NotebookMongoSync.generateFlashcards(
          _notebook.id, userId, 'Thẻ Ghi Nhớ');
      if (err == null && deck != null) {
        setState(() {
          _selectedFlashcardDeck = deck;
          _notebook.flashcards.add(deck);
          _currentFlashcardIndex = 0;
          _flashcardFlipped = false;
          _tabController.animateTo(3);
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi Flashcards: $err')));
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bgColor,
        colorScheme:
            ColorScheme.dark(primary: _accentColor, surface: _panelColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          leading: isMobile
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.source),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text(_notebook.title,
              style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: false,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: _accentColor,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'AI Chat'),
              Tab(icon: Icon(Icons.schema), text: 'Sơ đồ tư duy'),
              Tab(icon: Icon(Icons.quiz), text: 'Trắc nghiệm'),
              Tab(icon: Icon(Icons.style), text: 'Thẻ ghi nhớ'),
            ],
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveCurrentSource,
                tooltip: 'Lưu nguồn hiện tại',
              ),
            if (isMobile)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.build),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
        drawer: isMobile ? Drawer(child: _buildLeftPanel()) : null,
        endDrawer: isMobile ? Drawer(child: _buildRightPanel()) : null,
        body: Row(
          children: [
            if (!isMobile) ...[
              SizedBox(width: 300, child: _buildLeftPanel()),
              Container(width: 1, color: Colors.white10),
            ],
            Expanded(child: _buildCenterPanel()),
            if (!isMobile) ...[
              Container(width: 1, color: Colors.white10),
              SizedBox(width: 320, child: _buildRightPanel()),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: _panelColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text('Nguồn Học Tập',
                    style: TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.library_books,
                    color: Colors.white54, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Thêm nguồn mới',
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _addSourceDialog,
            ),
          ),
          const SizedBox(height: 16),

          // Source List
          Expanded(
            child: _notebook.sources.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description,
                            color: Colors.white38, size: 40),
                        const SizedBox(height: 8),
                        Text('Chưa có tài liệu nguồn nào.',
                            style:
                                TextStyle(color: _textColor.withOpacity(0.5))),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _notebook.sources.length,
                    itemBuilder: (context, index) {
                      final source = _notebook.sources[index];
                      final isSelected =
                          _selectedSource?.sourceId == source.sourceId;
                      return ListTile(
                        selected: isSelected,
                        selectedColor: _accentColor,
                        leading: Icon(Icons.description,
                            color: isSelected ? _accentColor : Colors.white60),
                        title: Text(source.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('${source.content.length} ký tự',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38)),
                        onTap: () {
                          setState(() {
                            _selectedSource = source;
                            _sourceViewerController.text = source.content;
                          });
                        },
                      );
                    },
                  ),
          ),

          // Active Source Document Editor
          if (_selectedSource != null) ...[
            Container(width: double.infinity, height: 1, color: Colors.white10),
            Container(
              padding: const EdgeInsets.all(12),
              color: _bgColor,
              height: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedSource!.title,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Trình soạn thảo',
                          style:
                              TextStyle(fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: _panelColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _sourceViewerController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(color: _textColor, fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(10),
                          hintText: 'Dán tài liệu học tập tại đây...',
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    final hasSources = _notebook.sources.isNotEmpty;

    return Container(
      color: _panelColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text('Studio Sáng Tạo',
                    style: TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.space_dashboard,
                    color: Colors.white54, size: 20),
              ],
            ),
          ),

          if (!hasSources)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                '⚠️ Hãy thêm tài liệu nguồn bên trái để kích hoạt các công cụ tạo bài học thông minh với AI!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.orangeAccent, fontSize: 13, height: 1.4),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildStudioToolCard(
                    icon: Icons.schema,
                    title: 'Tạo Sơ Đồ Tư Duy',
                    description: 'Phân tích tài liệu thành bản đồ trực quan.',
                    onTap: () => _generateAsset('mindmap'),
                  ),
                  const SizedBox(height: 12),
                  _buildStudioToolCard(
                    icon: Icons.quiz,
                    title: 'Tạo Bộ Trắc Nghiệm',
                    description: 'Tạo 5 câu hỏi kiểm tra độ hiểu bài.',
                    onTap: () => _generateAsset('quiz'),
                  ),
                  const SizedBox(height: 12),
                  _buildStudioToolCard(
                    icon: Icons.style,
                    title: 'Tạo Thẻ Ghi Nhớ',
                    description: 'Tổng hợp thuật ngữ thành bộ học nhanh.',
                    onTap: () => _generateAsset('flashcards'),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // History lists of generated items
          if (_notebook.mindmaps.isNotEmpty ||
              _notebook.quizzes.isNotEmpty ||
              _notebook.flashcards.isNotEmpty) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Text('TÀI SẢN ĐÃ TẠO',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _accentColor)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  ..._notebook.mindmaps.map((m) => ListTile(
                        leading: const Icon(Icons.schema,
                            size: 18, color: Colors.amber),
                        title:
                            Text(m.title, style: const TextStyle(fontSize: 12)),
                        onTap: () => setState(() {
                          _selectedMindmap = m;
                          _tabController.animateTo(1);
                        }),
                      )),
                  ..._notebook.quizzes.map((q) => ListTile(
                        leading: const Icon(Icons.quiz,
                            size: 18, color: Colors.green),
                        title:
                            Text(q.title, style: const TextStyle(fontSize: 12)),
                        onTap: () => setState(() {
                          _selectedQuiz = q;
                          _currentQuizQuestionIndex = 0;
                          _selectedQuizOption = null;
                          _quizAnswered = false;
                          _quizScore = 0;
                          _tabController.animateTo(2);
                        }),
                      )),
                  ..._notebook.flashcards.map((f) => ListTile(
                        leading: const Icon(Icons.style,
                            size: 18, color: Colors.purple),
                        title:
                            Text(f.title, style: const TextStyle(fontSize: 12)),
                        onTap: () => setState(() {
                          _selectedFlashcardDeck = f;
                          _currentFlashcardIndex = 0;
                          _flashcardFlipped = false;
                          _tabController.animateTo(3);
                        }),
                      )),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildStudioToolCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF2D2E32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(icon, size: 28, color: _accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 12, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPanel() {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildChatTab(),
        _buildMindmapTab(),
        _buildQuizTab(),
        _buildFlashcardsTab(),
      ],
    );
  }

  Widget _buildChatTab() {
    if (_isLoadingChat) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF48A9A6)));
    }
    return Container(
      color: _bgColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return DashChat(
            inputOptions: InputOptions(
              alwaysShowSend: true,
              inputDecoration: InputDecoration(
                hintText: "Hỏi trợ lý AI về tài liệu của bạn...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: _panelColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              inputTextStyle: const TextStyle(color: Colors.white),
            ),
            messageOptions: MessageOptions(
              maxWidth: constraints.maxWidth * 0.85,
              containerColor: _panelColor,
              textColor: _textColor,
              currentUserContainerColor: const Color(0xFF3B3B3B),
              currentUserTextColor: Colors.white,
              showTime: false,
            ),
            currentUser: currentUser,
            onSend: _sendMessage,
            messages: messages,
            messageListOptions: MessageListOptions(
              chatFooterBuilder:
                  messages.isEmpty ? _buildWelcomeEmptyState() : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'Tôi có thể giúp gì cho bạn hôm nay?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hệ thống AI đã kết nối trực tiếp với các tài liệu nguồn ở bảng bên trái. Bạn có thể hỏi tóm tắt, giải thích từ ngữ, hoặc so sánh các thông tin cực kỳ nhanh chóng!',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMindmapTab() {
    final item = _selectedMindmap ??
        (_notebook.mindmaps.isNotEmpty ? _notebook.mindmaps.last : null);
    if (item == null) {
      return _buildStudioPlaceholder('Sơ Đồ Tư Duy',
          'Nhấp vào nút "Tạo Sơ Đồ Tư Duy" ở bảng bên phải để bắt đầu.');
    }

    final nodes = item.graphData.nodes;
    final edges = item.graphData.edges;

    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return InteractiveViewer(
                maxScale: 3,
                minScale: 0.2,
                boundaryMargin: const EdgeInsets.all(2000),
                constrained: false,
                child: Container(
                  width:
                      constraints.maxWidth > 1200 ? constraints.maxWidth : 1200,
                  height:
                      constraints.maxHeight > 800 ? constraints.maxHeight : 800,
                  decoration: BoxDecoration(
                      color: _panelColor,
                      borderRadius: BorderRadius.circular(16)),
                  child: Stack(
                    children: [
                      // Render Connections / Lines
                      ...edges.map((edge) {
                        final srcNode = nodes.firstWhere(
                            (n) => n.id == edge.source,
                            orElse: () => nodes[0]);
                        final destNode = nodes.firstWhere(
                            (n) => n.id == edge.target,
                            orElse: () => nodes[0]);
                        return CustomPaint(
                          painter: _LinePainter(
                            from: Offset(srcNode.x + 80, srcNode.y + 25),
                            to: Offset(destNode.x + 80, destNode.y + 25),
                            color: _accentColor.withOpacity(0.6),
                          ),
                        );
                      }),
                      // Render Nodes
                      ...nodes.map((node) {
                        final isRoot = node.type == 'input';
                        return Positioned(
                          left: node.x,
                          top: node.y,
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: isRoot
                                  ? LinearGradient(colors: [
                                      _accentColor,
                                      const Color(0xFF2C6B69)
                                    ])
                                  : const LinearGradient(colors: [
                                      Color(0xFF2D2E32),
                                      Color(0xFF232427)
                                    ]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(2, 2))
                              ],
                            ),
                            child: Text(
                              node.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isRoot ? 13 : 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildQuizTab() {
    final quiz = _selectedQuiz ??
        (_notebook.quizzes.isNotEmpty ? _notebook.quizzes.last : null);
    if (quiz == null) {
      return _buildStudioPlaceholder('Bộ Trắc Nghiệm',
          'Hãy bấm nút sinh trắc nghiệm ở studio bên phải để AI trích xuất câu hỏi ôn tập.');
    }

    final questions = quiz.questions;
    if (questions.isEmpty) return Container();

    final currentQuestion = questions[_currentQuizQuestionIndex];

    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(quiz.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Đúng: $_quizScore/${questions.length}',
                    style: TextStyle(
                        color: _accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Progress bar
          LinearProgressIndicator(
            value: (_currentQuizQuestionIndex + 1) / questions.length,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
          ),
          const SizedBox(height: 32),

          // Question card
          Card(
            color: _panelColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Câu hỏi ${_currentQuizQuestionIndex + 1}: ${currentQuestion.questionText}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Options
          Expanded(
            child: ListView(
              children: currentQuestion.options.map((option) {
                final isSelected = _selectedQuizOption == option;
                final isCorrect = option == currentQuestion.correctAnswer;

                Color cardBg = const Color(0xFF2D2E32);
                Color borderCol = Colors.transparent;

                if (_quizAnswered) {
                  if (isCorrect) {
                    cardBg = Colors.green.withOpacity(0.15);
                    borderCol = Colors.green;
                  } else if (isSelected) {
                    cardBg = Colors.red.withOpacity(0.15);
                    borderCol = Colors.red;
                  }
                } else if (isSelected) {
                  borderCol = _accentColor;
                  cardBg = _accentColor.withOpacity(0.05);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderCol, width: 2),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _quizAnswered
                          ? null
                          : () {
                              setState(() {
                                _selectedQuizOption = option;
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(option,
                                    style: const TextStyle(fontSize: 14))),
                            if (_quizAnswered) ...[
                              if (isCorrect)
                                const Icon(Icons.check_circle,
                                    color: Colors.green)
                              else if (isSelected)
                                const Icon(Icons.cancel, color: Colors.red),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Navigation / Answer validation buttons
          if (!_quizAnswered)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _selectedQuizOption == null
                  ? null
                  : () {
                      setState(() {
                        _quizAnswered = true;
                        if (_selectedQuizOption ==
                            currentQuestion.correctAnswer) {
                          _quizScore++;
                        }
                      });
                    },
              child: const Text('Kiểm Tra Đáp Án',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  if (_currentQuizQuestionIndex < questions.length - 1) {
                    _currentQuizQuestionIndex++;
                    _selectedQuizOption = null;
                    _quizAnswered = false;
                  } else {
                    // Reset Quiz to play again
                    _currentQuizQuestionIndex = 0;
                    _selectedQuizOption = null;
                    _quizAnswered = false;
                    _quizScore = 0;
                  }
                });
              },
              child: Text(
                _currentQuizQuestionIndex < questions.length - 1
                    ? 'Câu Tiếp Theo'
                    : 'Chơi Lại',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildFlashcardsTab() {
    final deck = _selectedFlashcardDeck ??
        (_notebook.flashcards.isNotEmpty ? _notebook.flashcards.last : null);
    if (deck == null) {
      return _buildStudioPlaceholder('Thẻ Ghi Nhớ',
          'Bấm vào nốt tạo thẻ ghi nhớ ở studio bên phải để AI tóm tắt các định nghĩa học nhanh.');
    }

    final cards = deck.cards;
    if (cards.isEmpty) return Container();

    final currentCard = cards[_currentFlashcardIndex];

    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(deck.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${_currentFlashcardIndex + 1}/${cards.length}',
                  style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 32),

          // Flashcard Flip container
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _flashcardFlipped = !_flashcardFlipped;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: _flashcardFlipped
                      ? const LinearGradient(
                          colors: [Color(0xFF2C6B69), Color(0xFF1E3F3E)])
                      : const LinearGradient(
                          colors: [Color(0xFF2D2E32), Color(0xFF1E1F22)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ],
                ),
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _flashcardFlipped
                          ? 'ĐÁP ÁN / ĐỊNH NGHĨA'
                          : 'THUẬT NGỮ / CÂU HỎI',
                      style: TextStyle(
                          color: _accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _flashcardFlipped ? currentCard.back : currentCard.front,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    const Icon(Icons.touch_app,
                        color: Colors.white24, size: 24),
                    const SizedBox(height: 8),
                    const Text('Chạm để lật thẻ',
                        style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Next / Prev control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: _currentFlashcardIndex == 0
                    ? null
                    : () {
                        setState(() {
                          _currentFlashcardIndex--;
                          _flashcardFlipped = false;
                        });
                      },
              ),
              const Text('Chạm thẻ để xem đáp án',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentFlashcardIndex == cards.length - 1
                    ? null
                    : () {
                        setState(() {
                          _currentFlashcardIndex++;
                          _flashcardFlipped = false;
                        });
                      },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStudioPlaceholder(String assetName, String instruction) {
    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome,
              size: 64, color: _accentColor.withOpacity(0.4)),
          const SizedBox(height: 24),
          Text('Chưa có $assetName nào',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  _LinePainter({required this.from, required this.to, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
