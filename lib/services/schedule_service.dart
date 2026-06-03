import 'dart:convert';
import 'package:http/http.dart' as http;
import '../const.dart';

class TimeSlot {
  final String startTime;
  final String endTime;
  final String subject;
  final String roomOrLink;
  final String notebookId;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.roomOrLink,
    required this.notebookId,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      subject: json['subject'] ?? '',
      roomOrLink: json['room_or_link'] ?? '',
      notebookId: json['notebook_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime,
      'end_time': endTime,
      'subject': subject,
      'room_or_link': roomOrLink,
      'notebook_id': notebookId,
    };
  }
}

class TimetableDay {
  final String dayOfWeek;
  final List<TimeSlot> slots;

  TimetableDay({required this.dayOfWeek, required this.slots});

  factory TimetableDay.fromJson(Map<String, dynamic> json) {
    var list = json['slots'] as List? ?? [];
    List<TimeSlot> slotList = list.map((i) => TimeSlot.fromJson(i)).toList();
    return TimetableDay(
      dayOfWeek: json['day_of_week'] ?? '',
      slots: slotList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'slots': slots.map((s) => s.toJson()).toList(),
    };
  }
}

class TodoTask {
  final String taskId;
  final String title;
  final String? dueDate;
  final bool isCompleted;
  final String notebookId;

  TodoTask({
    required this.taskId,
    required this.title,
    this.dueDate,
    required this.isCompleted,
    required this.notebookId,
  });

  factory TodoTask.fromJson(Map<String, dynamic> json) {
    return TodoTask(
      taskId: json['task_id'] ?? '',
      title: json['title'] ?? '',
      dueDate: json['due_date'],
      isCompleted: json['is_completed'] ?? false,
      notebookId: json['notebook_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'title': title,
      'due_date': dueDate,
      'is_completed': isCompleted,
      'notebook_id': notebookId,
    };
  }
}

class UserSchedule {
  final String userId;
  final List<TimetableDay> timetable;
  final List<TodoTask> todoList;

  UserSchedule({
    required this.userId,
    required this.timetable,
    required this.todoList,
  });

  factory UserSchedule.fromJson(Map<String, dynamic> json) {
    var tableList = json['timetable'] as List? ?? [];
    var todoListRaw = json['todo_list'] as List? ?? [];
    return UserSchedule(
      userId: json['user_id'] ?? '',
      timetable: tableList.map((i) => TimetableDay.fromJson(i)).toList(),
      todoList: todoListRaw.map((i) => TodoTask.fromJson(i)).toList(),
    );
  }
}

class ScheduleService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = fastApiBaseUrl.endsWith('/') ? fastApiBaseUrl.substring(0, fastApiBaseUrl.length - 1) : fastApiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static Future<(UserSchedule?, String?)> fetchSchedule(String userId) async {
    try {
      final res = await http.get(_uri('/api/schedules', {'userId': userId}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (UserSchedule.fromJson(data), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<String?> updateTimetable(String userId, List<TimetableDay> timetable) async {
    try {
      final res = await http.post(
        _uri('/api/schedules/timetable', {'userId': userId}),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(timetable.map((t) => t.toJson()).toList()),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<(String?, String?)> addOrUpdateTodo(String userId, TodoTask task) async {
    try {
      final res = await http.post(
        _uri('/api/schedules/todo', {'userId': userId}),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(task.toJson()),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (map['task_id'] as String?, null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<String?> deleteTodo(String userId, String taskId) async {
    try {
      final res = await http.delete(_uri('/api/schedules/todo/$taskId', {'userId': userId}));
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }
}
