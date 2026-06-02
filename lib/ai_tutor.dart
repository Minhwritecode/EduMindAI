import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_learning_application/const.dart'
    show geminiGenerationModel, profileIconAsset;
import 'package:smart_learning_application/gemini_helpers.dart';
import 'package:smart_learning_application/widgets/tts_button.dart';

class AiTutorPage extends StatefulWidget {
  const AiTutorPage({super.key});

  @override
  _AiTutorPageState createState() => _AiTutorPageState();
}

class _AiTutorPageState extends State<AiTutorPage> {
  final Gemini gemini = Gemini.instance;

  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "AI Tutor",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF48A9A6),
        centerTitle: true,
        title: const Text(
          "AI Tutor",
        ),
        actions: [
          Builder(builder: (_) {
            String latestAiText = '';
            for (final m in messages) {
              if (m.user == geminiUser) {
                latestAiText = m.text;
                break;
              }
            }
            return TtsButton(text: latestAiText);
          }),
        ],
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(profileIconAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: DashChat(
        inputOptions: InputOptions(trailing: [
          IconButton(
            onPressed: _sendMediaMessage,
            icon: const Icon(
              Icons.image,
            ),
          )
        ]),
        currentUser: currentUser,
        onSend: _sendMessage,
        messages: messages,
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });
    try {
      String question = chatMessage.text;
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }
      gemini
          .streamGenerateContent(
            question,
            images: images,
            modelName: geminiGenerationModel,
          )
          .listen((event) {
        ChatMessage? lastMessage = messages.firstOrNull;
        if (lastMessage != null && lastMessage.user == geminiUser) {
          lastMessage = messages.removeAt(0);
          String response = event.content?.parts?.fold(
              "", (previous, current) => "$previous ${current.text}") ??
              "";
          lastMessage.text += response;
          setState(
                () {
              messages = [lastMessage!, ...messages];
            },
          );
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
      }, onError: _onGeminiStreamError, cancelOnError: true);
    } catch (e) {
      _onGeminiStreamError(e);
    }
  }

  void _onGeminiStreamError(Object e) {
    if (!mounted) return;
    final msg = geminiUserMessage(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {
      messages = [
        ChatMessage(
          user: geminiUser,
          createdAt: DateTime.now(),
          text: msg,
        ),
        ...messages,
      ];
    });
  }

  void _sendMediaMessage() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: "Describe this picture?",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "",
            type: MediaType.image,
          )
        ],
      );
      _sendMessage(chatMessage);
    }
  }
}
