import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'focus_mode_page.dart';
import 'my_learning_page.dart';
import 'schedule_analyze_page.dart';
import 'state/notebook_context_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedPreference;

  @override
  void dispose() {
    super.dispose();
  }

  // Dummy list of subjects for demonstration
  List<String> subjectNames = [
    'Maths', 'Science', 'History', 'Language', 'Arts',
    'Geography', 'Music', 'Computer', 'Physics', 'Biology',
  ];

  // Example data placeholders for recommended videos
  List<String> videoTitles = [
    'C++ Basics in One Shot - Strivers A2Z DSA Course - L1',
    'Introduction to JavaScript + Setup | JavaScript Tutorial in Hindi #1',
    'Python Tutorial for Beginners | Learn Python in 1.5 Hours',
    'ApnaCollegeOfficial which Coding Platform should I study from?',
    'Web Development Tutorial for Beginners (2024 Edition)',
  ];

  List<String> videoImageUrls = [
    'https://th.bing.com/th/id/OIP.0STrpvtmnpiN8MxYI-xUPwAAAA?rs=1&pid=ImgDetMain',
    'https://www.codewithharry.com/_next/image/?url=https:%2F%2Fcwh-full-next-space.fra1.digitaloceanspaces.com%2Fvideoseries%2Fultimate-js-tutorial-hindi-1%2FJS-Thumb.jpg&w=828&q=75',
    'https://th.bing.com/th/id/OIP.raiOFsxSpMFzOFwa2TXUmQAAAA?rs=1&pid=ImgDetMain',
    'https://i.ytimg.com/vi/qTph1pj_rCo/maxresdefault.jpg',
    'https://www.someurl.com/your-image4.jpg',
  ];

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
      // Navigate to Home (current page)
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyLearningPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleAnalyzePage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FocusModePage()),
        );
        break;
    }
  }

  void _navigateToFocusMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FocusModePage()),
    );
  }

  final TextEditingController _taskController = TextEditingController();
  List<String> tasks = [];

  void _addTask(String task) {
    setState(() {
      tasks.add(task);
      _taskController.clear(); // Clear input field after adding task
    });
  }

  void _deleteTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF48A9A6),
        title: const Text('PMDEduMind'),
        actions: const [
          /*IconButton(
            icon: Image.asset(
              'lib/assets/profile_icon.jpg', // Replace with your asset image path
              width: 30,
              height: 30,
            ),
            onPressed: () {
              // Navigate to profile screen or show profile menu
            },
          ),*/
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF48A9A6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('lib/assets/profile_icon.jpg'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tien Minh', 
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Settings'),
              onTap: () {
                // Handle navigation to settings
              },
            ),
            ListTile(
              title: const Text('FAQ'),
              onTap: () {
                // Handle navigation to FAQ
              },
            ),
            // Add more list items as needed
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search courses',
                        suffixStyle: TextStyle(color: Color(0xFF531002)),
                        suffixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // Adjust spacing between search bar and dropdown button
                  DropdownButton<String>(
                    hint: const Text(
                      'Preference',
                      style: TextStyle(color: Color(0xFF531002)),
                    ),
                    value: _selectedPreference,
                    items: ['Visual', 'Auditory', 'Reading/Writing', 'Kinesthetic']
                        .map((String preference) {
                      return DropdownMenuItem<String>(
                        value: preference,
                        child: Text(
                          preference,
                          style: const TextStyle(color: Colors.black87), // Adjust text color
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPreference = newValue;
                      });
                      // Implement logic to filter based on preference
                    },
                    icon: const Icon(Icons.arrow_drop_down),
                    underline: Container(),
                    elevation: 0,
                    style: const TextStyle(color: Color(0xFFFDB8AF)), // Set dropdown button text color
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Recommended for you',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: videoTitles.length,
                  itemBuilder: (BuildContext context, int index) {
                    String videoTitle = videoTitles[index];
                    String imageURL = videoImageUrls[index]; // Assuming you have a list of URLs

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 200, // Fixed width for each card
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                child: Image.network(
                                  imageURL, // Use the actual image URL here
                                  width: 200,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  videoTitle,
                                  maxLines: 2, // Limit the number of lines
                                  overflow: TextOverflow.ellipsis, // Handle overflow
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Subjects',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: subjectNames.length,
                  itemBuilder: (BuildContext context, int index) {
                    String subjectName = subjectNames[index];
                    return _buildSubjectCard(subjectName, index);
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your Tasks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      decoration: InputDecoration(
                        hintText: 'Enter task',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            _addTask(_taskController.text.trim());
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(tasks[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteTask(index);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15.0),
            topRight: Radius.circular(15.0),
          ),
          color: Color(0xFF48A9A6),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.white, // Color of selected item's icon and text
          unselectedItemColor: Colors.white.withOpacity(0.6), // Color of unselected item's icon and text
          type: BottomNavigationBarType.fixed, // Fixes white background issue when adding more than 3 items
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'My Learning',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'My schedule',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer),
              label: 'Pomodoro',
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSubjectCard(String subjectName, int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 150,
        child: Card(
          color: Colors.grey[200], // Neutral color for the card background
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.book,
                  size: 40,
                  color: Color(0xFF48A9A6), // Adjust the book icon color
                ),
                const SizedBox(height: 8),
                Text(
                  subjectName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
