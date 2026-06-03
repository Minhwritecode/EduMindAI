import 'dart:convert';
import 'package:http/http.dart' as http;
import '../const.dart';

class SourceItem {
  final String sourceId;
  final String title;
  final String sourceType;
  final String content;
  final String fileUrl;

  SourceItem({
    required this.sourceId,
    required this.title,
    required this.sourceType,
    required this.content,
    required this.fileUrl,
  });

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      sourceId: json['source_id'] ?? '',
      title: json['title'] ?? '',
      sourceType: json['source_type'] ?? 'text',
      content: json['content'] ?? '',
      fileUrl: json['file_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source_id': sourceId,
      'title': title,
      'source_type': sourceType,
      'content': content,
      'file_url': fileUrl,
    };
  }
}

class MindmapNode {
  final String id;
  final String type;
  final String label;
  final double x;
  final double y;

  MindmapNode({
    required this.id,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
  });

  factory MindmapNode.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final pos = json['position'] as Map<String, dynamic>? ?? {};
    return MindmapNode(
      id: json['id'] ?? '',
      type: json['type'] ?? 'default',
      label: data['label'] ?? '',
      x: (pos['x'] as num? ?? 0.0).toDouble(),
      y: (pos['y'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': {'label': label},
      'position': {'x': x, 'y': y},
    };
  }
}

class MindmapEdge {
  final String id;
  final String source;
  final String target;

  MindmapEdge({
    required this.id,
    required this.source,
    required this.target,
  });

  factory MindmapEdge.fromJson(Map<String, dynamic> json) {
    return MindmapEdge(
      id: json['id'] ?? '',
      source: json['source'] ?? '',
      target: json['target'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'target': target,
    };
  }
}

class MindmapGraphData {
  final List<MindmapNode> nodes;
  final List<MindmapEdge> edges;

  MindmapGraphData({required this.nodes, required this.edges});

  factory MindmapGraphData.fromJson(Map<String, dynamic> json) {
    var nodeList = json['nodes'] as List? ?? [];
    var edgeList = json['edges'] as List? ?? [];
    return MindmapGraphData(
      nodes: nodeList.map((i) => MindmapNode.fromJson(i)).toList(),
      edges: edgeList.map((i) => MindmapEdge.fromJson(i)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }
}

class MindmapItem {
  final String mindmapId;
  final String title;
  final MindmapGraphData graphData;

  MindmapItem({
    required this.mindmapId,
    required this.title,
    required this.graphData,
  });

  factory MindmapItem.fromJson(Map<String, dynamic> json) {
    return MindmapItem(
      mindmapId: json['mindmap_id'] ?? '',
      title: json['title'] ?? '',
      graphData: MindmapGraphData.fromJson(json['graph_data'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mindmap_id': mindmapId,
      'title': title,
      'graph_data': graphData.toJson(),
    };
  }
}

class QuizQuestion {
  final String questionText;
  final List<String> options;
  final String correctAnswer;

  QuizQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    var opts = json['options'] as List? ?? [];
    return QuizQuestion(
      questionText: json['question_text'] ?? '',
      options: opts.map((i) => i.toString()).toList(),
      correctAnswer: json['correct_answer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionText,
      'options': options,
      'correct_answer': correctAnswer,
    };
  }
}

class QuizItem {
  final String quizId;
  final String title;
  final List<QuizQuestion> questions;

  QuizItem({
    required this.quizId,
    required this.title,
    required this.questions,
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    var qList = json['questions'] as List? ?? [];
    return QuizItem(
      quizId: json['quiz_id'] ?? '',
      title: json['title'] ?? '',
      questions: qList.map((i) => QuizQuestion.fromJson(i)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'title': title,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class FlashcardItem {
  final String front;
  final String back;

  FlashcardItem({required this.front, required this.back});

  factory FlashcardItem.fromJson(Map<String, dynamic> json) {
    return FlashcardItem(
      front: json['front'] ?? '',
      back: json['back'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'front': front,
      'back': back,
    };
  }
}

class FlashcardDeck {
  final String deckId;
  final String title;
  final List<FlashcardItem> cards;

  FlashcardDeck({
    required this.deckId,
    required this.title,
    required this.cards,
  });

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    var cList = json['cards'] as List? ?? [];
    return FlashcardDeck(
      deckId: json['deck_id'] ?? '',
      title: json['title'] ?? '',
      cards: cList.map((i) => FlashcardItem.fromJson(i)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deck_id': deckId,
      'title': title,
      'cards': cards.map((c) => c.toJson()).toList(),
    };
  }
}

class Notebook {
  final String id;
  final String title;
  final String description;
  final String text;
  final List<SourceItem> sources;
  final List<MindmapItem> mindmaps;
  final List<QuizItem> quizzes;
  final List<FlashcardDeck> flashcards;

  Notebook({
    required this.id,
    required this.title,
    this.description = '',
    required this.text,
    this.sources = const [],
    this.mindmaps = const [],
    this.quizzes = const [],
    this.flashcards = const [],
  });

  factory Notebook.fromJson(Map<String, dynamic> json) {
    var sList = json['sources'] as List? ?? [];
    var mList = json['mindmaps'] as List? ?? [];
    var qList = json['quizzes'] as List? ?? [];
    var fList = json['flashcards'] as List? ?? [];

    return Notebook(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Notebook',
      description: json['description'] ?? '',
      text: json['text'] ?? '',
      sources: sList.map((i) => SourceItem.fromJson(i)).toList(),
      mindmaps: mList.map((i) => MindmapItem.fromJson(i)).toList(),
      quizzes: qList.map((i) => QuizItem.fromJson(i)).toList(),
      flashcards: fList.map((i) => FlashcardDeck.fromJson(i)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'text': text,
      'sources': sources.map((s) => s.toJson()).toList(),
      'mindmaps': mindmaps.map((m) => m.toJson()).toList(),
      'quizzes': quizzes.map((q) => q.toJson()).toList(),
      'flashcards': flashcards.map((f) => f.toJson()).toList(),
    };
  }
}

class NotebookMongoSync {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = fastApiBaseUrl.endsWith('/') ? fastApiBaseUrl.substring(0, fastApiBaseUrl.length - 1) : fastApiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static Future<(List<Notebook>?, String?)> fetchNotebooks(String userId) async {
    try {
      final res = await http.get(_uri('/api/notebooks', {'userId': userId}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final docs = map['notebooks'] as List<dynamic>? ?? [];
      
      List<Notebook> notebooks = docs.map((doc) => Notebook.fromJson(doc as Map<String, dynamic>)).toList();
      return (notebooks, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<(String?, String?)> saveNotebook({
    required String userId, 
    required String id, 
    required String title,
    required String description,
    required String text,
    List<SourceItem> sources = const [],
    List<MindmapItem> mindmaps = const [],
    List<QuizItem> quizzes = const [],
    List<FlashcardDeck> flashcards = const [],
  }) async {
    try {
      final notebook = Notebook(
        id: id,
        title: title,
        description: description,
        text: text,
        sources: sources,
        mindmaps: mindmaps,
        quizzes: quizzes,
        flashcards: flashcards,
      );

      final bodyData = notebook.toJson();
      bodyData['userId'] = userId;

      final res = await http.post(
        _uri('/api/notebooks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (map['id'] as String?, null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<String?> deleteNotebook(String userId, String notebookId) async {
    try {
      final res = await http.delete(_uri('/api/notebooks', {'userId': userId, 'id': notebookId}));
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<(String?, String?)> uploadSource({
    required String notebookId,
    required String userId,
    required String title,
    required String content,
    String sourceType = "text",
    String fileUrl = "",
  }) async {
    try {
      final res = await http.post(
        _uri('/api/notebooks/$notebookId/sources', {
          'userId': userId,
          'title': title,
          'content': content,
          'source_type': sourceType,
          'file_url': fileUrl,
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (map['source_id'] as String?, null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  // LLM generation triggers
  static Future<(MindmapItem?, String?)> generateMindmap(String notebookId, String userId, String title) async {
    try {
      final res = await http.post(_uri('/api/notebooks/$notebookId/generate/mindmap', {
        'userId': userId,
        'title': title,
      }));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (MindmapItem.fromJson(map['mindmap']), null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<(QuizItem?, String?)> generateQuiz(String notebookId, String userId, String title) async {
    try {
      final res = await http.post(_uri('/api/notebooks/$notebookId/generate/quiz', {
        'userId': userId,
        'title': title,
      }));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (QuizItem.fromJson(map['quiz']), null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<(FlashcardDeck?, String?)> generateFlashcards(String notebookId, String userId, String title) async {
    try {
      final res = await http.post(_uri('/api/notebooks/$notebookId/generate/flashcards', {
        'userId': userId,
        'title': title,
      }));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (FlashcardDeck.fromJson(map['flashcard']), null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<(String?, String?)> uploadSourceFile({
    required String notebookId,
    required String userId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      final base = fastApiBaseUrl.endsWith('/') ? fastApiBaseUrl.substring(0, fastApiBaseUrl.length - 1) : fastApiBaseUrl;
      final uri = Uri.parse('$base/api/notebooks/$notebookId/upload');
      
      final request = http.MultipartRequest('POST', uri)
        ..fields['userId'] = userId
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ),
        );

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (map['source_id'] as String?, null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }
}
