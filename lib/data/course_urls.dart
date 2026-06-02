/// Centralized course URL data for the dashboard.
/// Each category maps to a list of provider entries (name + URL).
/// The first URL in each list is used as the default when a CourseCard is tapped.

class CourseUrlEntry {
  final String provider;
  final String url;
  const CourseUrlEntry(this.provider, this.url);
}

class CourseUrls {
  /// Map of category name → list of provider URLs.
  static const Map<String, List<Map<String, String>>> subjectUrls = {
    // ────────────────────────────────────────────────
    // 💻 1. IT, Lập trình & Dữ liệu
    // ────────────────────────────────────────────────
    'IT & Tech': [
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/it-and-computer-science'},
      {'provider': 'Pluralsight', 'url': 'https://www.pluralsight.com/browse/software-development'},
      {'provider': 'Pluralsight', 'url': 'https://www.pluralsight.com/browse/it-ops'},
      {'provider': 'Skillshare', 'url': 'https://www.skillshare.com/en/browse/technology'},
      {'provider': 'LinkedIn Learning', 'url': 'https://www.linkedin.com/learning/topics/technology'},
    ],

    // ────────────────────────────────────────────────
    // 📈 2. Kinh doanh, Quản trị & Marketing
    // ────────────────────────────────────────────────
    'Business': [
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/business-and-management'},
      {'provider': 'Skillshare', 'url': 'https://www.skillshare.com/en/browse/business'},
      {'provider': 'LinkedIn Learning', 'url': 'https://www.linkedin.com/learning/topics/business'},
    ],

    // ────────────────────────────────────────────────
    // 🎨 3. Sáng tạo, Thiết kế & Nghệ thuật
    // ────────────────────────────────────────────────
    'Design & Arts': [
      {'provider': 'Skillshare', 'url': 'https://www.skillshare.com/en/browse/creative'},
      {'provider': 'Domestika', 'url': 'https://www.domestika.org/en/courses'},
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/creative-arts-and-media'},
      {'provider': 'LinkedIn Learning', 'url': 'https://www.linkedin.com/learning/topics/creative'},
    ],

    // ────────────────────────────────────────────────
    // 🗣️ 4. Ngôn ngữ & Văn hóa
    // ────────────────────────────────────────────────
    'Languages': [
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/language'},
      {'provider': 'Babbel', 'url': 'https://www.babbel.com/'},
    ],

    // ────────────────────────────────────────────────
    // 🧠 5. Phát triển bản thân, Tâm lý & Sức khỏe
    // ────────────────────────────────────────────────
    'Health & Psychology': [
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/psychology-and-mental-health'},
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/healthcare-and-medicine'},
      {'provider': 'Skillshare', 'url': 'https://www.skillshare.com/en/browse/lifestyle'},
    ],

    // ────────────────────────────────────────────────
    // 📚 6. Giáo dục & Khoa học cơ bản
    // ────────────────────────────────────────────────
    'Teaching & STEM': [
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/teaching'},
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/science-engineering-and-maths'},
      {'provider': 'FutureLearn', 'url': 'https://www.futurelearn.com/subjects/law'},
    ],
  };

  /// Helper: get just the URL strings for a given subject key.
  static List<String> urlsFor(String subject) {
    return subjectUrls[subject]
            ?.map((e) => e['url']!)
            .toList() ??
        [];
  }

  /// Helper: get the first URL for a given subject, or empty string.
  static String firstUrl(String subject) {
    final urls = urlsFor(subject);
    return urls.isNotEmpty ? urls.first : '';
  }

  /// Icon data for each category (used by CourseCard).
  static const Map<String, int> subjectIcons = {
    'IT & Tech': 0xe1e3,      // Icons.computer
    'Business': 0xe0e0,       // Icons.business
    'Design & Arts': 0xe40a,  // Icons.palette
    'Languages': 0xe8e2,      // Icons.translate
    'Health & Psychology': 0xe3dc, // Icons.psychology
    'Teaching & STEM': 0xe80c,    // Icons.science
  };
}
