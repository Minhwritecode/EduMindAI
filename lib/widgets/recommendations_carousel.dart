import 'package:flutter/material.dart';
import 'package:smart_learning_application/widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

class RecommendationsCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> recommendations;

  const RecommendationsCarousel({
    super.key,
    required this.recommendations,
  });

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _difficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'hard':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const Center(
        child: Text('Không có gợi ý nào', style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final rec = recommendations[index];
          final title = rec['title'] ?? '';
          final category = rec['category'] ?? '';
          final difficulty = rec['difficulty'] ?? 'Easy';
          final rating = rec['rating']?.toString() ?? '4.0';
          final url = rec['url'] ?? '';
          final diffColor = _difficultyColor(difficulty);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 200,
              child: GlassCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // placeholder image
                  Container(
                    height: 80,
                    color: const Color(0xFFE0F2F1),
                    child: const Center(
                      child: Icon(Icons.school_outlined, size: 36, color: Color(0xFF48A9A6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          difficulty,
                          style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(rating, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: url.isNotEmpty ? () => _openUrl(url) : null,
                      child: const Text('Mở', style: TextStyle(color: Color(0xFF48A9A6))),
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
