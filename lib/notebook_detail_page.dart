import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'services/notebook_mongo_sync.dart';
import 'state/notebook_context_state.dart';

class NotebookDetailPage extends StatefulWidget {
  final Notebook notebook;

  const NotebookDetailPage({super.key, required this.notebook});

  @override
  State<NotebookDetailPage> createState() => _NotebookDetailPageState();
}

class _NotebookDetailPageState extends State<NotebookDetailPage> {
  late Notebook _notebook;
  late TextEditingController _textController;
  bool _isSaving = false;

  Gemini? gemini;
  List<ChatMessage> messages = [];
  
  final ChatUser currentUser = ChatUser(id: "0", firstName: "You");
  final ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "AI Tutor",
    profileImage: "https://cdn-icons-png.flaticon.com/512/8649/8649595.png",
  );

  final Color _bgColor = const Color(0xFF131314);
  final Color _panelColor = const Color(0xFF1E1F22);
  final Color _accentColor = const Color(0xFF48A9A6); // Keeping app's primary accent
  final Color _textColor = const Color(0xFFE3E3E3);

  @override
  void initState() {
    super.initState();
    try {
      gemini = Gemini.instance;
    } catch (e) {
      print('Gemini not initialized: $e');
    }
    _notebook = widget.notebook;
    _textController = TextEditingController(text: _notebook.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveNotebook() async {
    setState(() => _isSaving = true);
    final userId = context.read<NotebookContextState>().userId;
    
    final (id, err) = await NotebookMongoSync.saveNotebook(
      userId: userId,
      id: _notebook.id,
      title: _notebook.title,
      text: _textController.text,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (err == null) {
          _notebook = Notebook(id: id ?? _notebook.id, title: _notebook.title, text: _textController.text);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu nguồn')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $err')));
        }
      });
    }
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });

    try {
      String contextText = _textController.text.trim();
      String systemPrompt = contextText.isNotEmpty
          ? "Dựa vào nội dung nguồn sau đây để trả lời câu hỏi. Nếu không có trong nguồn, hãy nói rõ.\n\nNguồn:\n$contextText\n\nCâu hỏi:\n"
          : "";
      
      String questionForGemini = systemPrompt + chatMessage.text;

      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }

      if (gemini == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa cấu hình API Gemini')));
        return;
      }

      gemini!.streamGenerateContent(
        questionForGemini,
        images: images,
      ).listen((event) {
        ChatMessage? lastMessage = messages.firstOrNull;
        if (lastMessage != null && lastMessage.user == geminiUser) {
          lastMessage = messages.removeAt(0);
          String response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          lastMessage.text += response;
          setState(() {
            messages = [lastMessage!, ...messages];
          });
        } else {
          String response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          ChatMessage message = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: response,
          );
          setState(() {
            messages = [message, ...messages];
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _triggerToolPrompt(String toolName) {
    String prompt = "Hãy giúp tôi tạo $toolName dựa trên các nguồn tài liệu hiện có.";
    _sendMessage(ChatMessage(
      user: currentUser,
      createdAt: DateTime.now(),
      text: prompt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bgColor,
        colorScheme: ColorScheme.dark(
          primary: _accentColor,
          surface: _panelColor,
        ),
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
          title: Text(_notebook.title, style: TextStyle(color: _textColor, fontSize: 18)),
          centerTitle: false,
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveNotebook,
                tooltip: 'Lưu',
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
                Text('Nguồn', style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.library_books, color: Colors.white54, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Thêm nguồn', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                // Focus text area or expand options
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm nguồn mới trên web...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.public, color: Colors.white54),
                suffixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.description, color: Colors.white38, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'Các nguồn đã lưu sẽ xuất hiện ở đây',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhập văn bản vào đây để làm nguồn cho ghi chú của bạn.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Dán tài liệu hoặc nội dung tại đây...',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    final tools = [
      {'icon': Icons.audiotrack, 'title': 'Tổng quan...', 'action': 'tổng quan âm thanh'},
      {'icon': Icons.slideshow, 'title': 'Bản trình...', 'action': 'bản trình bày'},
      {'icon': Icons.article, 'title': 'Báo cáo', 'action': 'báo cáo tóm tắt'},
      {'icon': Icons.style, 'title': 'Thẻ ghi...', 'action': 'bộ thẻ ghi nhớ'},
      {'icon': Icons.quiz, 'title': 'Bài kiểm...', 'action': 'bài kiểm tra trắc nghiệm'},
      {'icon': Icons.schema, 'title': 'Bản đồ...', 'action': 'bản đồ tư duy'},
      {'icon': Icons.table_chart, 'title': 'Bảng dữ...', 'action': 'bảng dữ liệu'},
    ];

    return Container(
      color: _panelColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text('Studio', style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.space_dashboard, color: Colors.white54, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return Material(
                  color: const Color(0xFF2D2E32),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (MediaQuery.of(context).size.width < 900) {
                        Navigator.pop(context); // Close drawer if mobile
                      }
                      _triggerToolPrompt(tool['action'] as String);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          Icon(tool['icon'] as IconData, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tool['title'] as String,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 14, color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.auto_fix_high, color: Colors.white54, size: 32),
                const SizedBox(height: 16),
                const Text(
                  'Đầu ra của Studio sẽ được lưu ở đây.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sau khi thêm nguồn, hãy nhấp để thêm Tổng quan bằng âm thanh, Hướng dẫn học tập, Bản đồ tư duy và nhiều thông tin khác!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.post_add, color: Colors.black87),
                  label: const Text('Thêm ghi chú', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {},
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCenterPanel() {
    return Container(
      color: _bgColor,
      child: DashChat(
        inputOptions: InputOptions(
          alwaysShowSend: true,
          showTraillingBeforeSend: true,
          inputDecoration: InputDecoration(
            hintText: "Đặt câu hỏi hoặc tạo nội dung",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: _panelColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          inputTextStyle: const TextStyle(color: Colors.white),
          trailing: [
            IconButton(
              icon: const Icon(Icons.image, color: Colors.white54),
              onPressed: () async {
                ImagePicker picker = ImagePicker();
                XFile? file = await picker.pickImage(source: ImageSource.gallery);
                if (file != null) {
                  _sendMessage(ChatMessage(
                    user: currentUser,
                    createdAt: DateTime.now(),
                    text: "Hãy phân tích hình ảnh này dựa trên nguồn của tôi.",
                    medias: [ChatMedia(url: file.path, fileName: "", type: MediaType.image)],
                  ));
                }
              },
            ),
          ]
        ),
        messageOptions: MessageOptions(
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
          chatFooterBuilder: messages.isEmpty ? _buildWelcomeEmptyState() : null,
        ),
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
            'Hãy bắt đầu sổ ghi chú của\nbạn...',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 24),
          const Text(
            'Đây là một canvas trống để bạn tìm hiểu, sáng tạo hoặc tiến bộ trong\nmột lĩnh vực mới. Tôi có thể giúp bạn bắt đầu hoặc bạn có thể tự tiến\nhành thêm nguồn.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          const Text(
            'Bạn muốn sổ ghi chú này giúp bạn làm gì?',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSuggestionChip('Bắt đầu một dự án'),
              _buildSuggestionChip('Tìm hiểu hoặc nắm bắt thông tin'),
              _buildSuggestionChip('Tạo podcast, video, bản trình bày, v.v.'),
              _buildSuggestionChip('Khác...'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Colors.white70)),
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _textController.text = _textController.text + (text == 'Khác...' ? '' : '\nTôi muốn: $text');
      },
    );
  }
}
