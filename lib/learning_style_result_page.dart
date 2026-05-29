import 'package:flutter/material.dart';
import 'package:smart_learning_application/const.dart' show profileIconAsset;
import 'package:smart_learning_application/home_page_visual.dart';

class LearningStyleResultPage extends StatelessWidget {
  final String selectedStyle; // Placeholder for selected learning style

  const LearningStyleResultPage({super.key, required this.selectedStyle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(profileIconAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Heading: Your learning style is
                const Text(
                  'Your learning style is',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Selected learning style
                Text(
                  selectedStyle,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Network image
                Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(profileIconAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Button to navigate back to homepage
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                    ); // Navigate back to previous screen (homepage)
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(const Color(0xFF48A9A6)),
                    padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Back to Homepage',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
