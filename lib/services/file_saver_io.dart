import 'dart:io';

void saveTextFileImpl(String content, String fileName) {
  try {
    final file = File(fileName);
    file.writeAsStringSync(content);
  } catch (e) {
    print('Failed to save file locally: $e');
  }
}
