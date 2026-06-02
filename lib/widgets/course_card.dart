import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_learning_application/widgets/glass_card.dart';
import 'package:smart_learning_application/data/course_urls.dart';

/// A glass‑morphic card representing a subject category.
/// When tapped it opens a bottom sheet listing all providers for the subject.
/// Each provider can be opened in an external browser via [url_launcher].
class CourseCard extends StatelessWidget {
  final String subject;
  final List<String> providerUrls;
  final double width;
  final IconData? icon;

  const CourseCard({
    super.key,
    required this.subject,
    required this.providerUrls,
    this.width = 150,
    this.icon,
  });

  /// Map subject name → Material icon.
  static const Map<String, IconData> _subjectIcons = {
    'IT & Tech': Icons.computer,
    'Business': Icons.business,
    'Design & Arts': Icons.palette,
    'Languages': Icons.translate,
    'Health & Psychology': Icons.psychology,
    'Teaching & STEM': Icons.science,
  };

  /// Map subject name → gradient colours.
  static const Map<String, List<Color>> _subjectGradients = {
    'IT & Tech': [Color(0xFF667eea), Color(0xFF764ba2)],
    'Business': [Color(0xFF43e97b), Color(0xFF38f9d7)],
    'Design & Arts': [Color(0xFFfa709a), Color(0xFFfee140)],
    'Languages': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    'Health & Psychology': [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
    'Teaching & STEM': [Color(0xFFfccb90), Color(0xFFd57eeb)],
  };

  void _showProviderSheet(BuildContext context) {
    final providers = CourseUrls.subjectUrls[subject] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.7,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                subject,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002131),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${providers.length} nhà cung cấp',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: providers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = providers[i];
                    final providerName = entry['provider'] ?? '';
                    final url = entry['url'] ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: (_subjectGradients[subject]?.first ??
                                const Color(0xFF48A9A6))
                            .withOpacity(0.15),
                        child: Icon(
                          Icons.open_in_new,
                          color: _subjectGradients[subject]?.first ??
                              const Color(0xFF48A9A6),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        providerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        Uri.parse(url).host,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.grey),
                      onTap: () async {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardIcon = icon ?? _subjectIcons[subject] ?? Icons.book;
    final gradient = _subjectGradients[subject] ??
        [const Color(0xFF48A9A6), const Color(0xFF48A9A6)];

    return SizedBox(
      width: width,
      child: GlassCard(
        margin: const EdgeInsets.only(right: 10),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showProviderSheet(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    gradient[0].withOpacity(0.15),
                    gradient[1].withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: gradient[0].withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cardIcon, size: 28, color: gradient[0]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002131),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${providerUrls.length} courses',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
