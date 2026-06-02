import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/state/notebook_context_state.dart';
import 'package:smart_learning_application/services/user_data_sync.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedLearningStyle = 'Visual';
  bool _isLoading = false;

  final List<String> _learningStyles = [
    'Visual',
    'Auditory',
    'Reading/Writing',
    'Kinesthetic',
  ];

  @override
  void initState() {
    super.initState();
    final nb = context.read<NotebookContextState>();
    _nameController.text = nb.userName;
    _selectedLearningStyle = nb.learningStyle.isNotEmpty ? nb.learningStyle : 'Visual';
    _fetchProfileFromServer();
  }

  Future<void> _fetchProfileFromServer() async {
    final nb = context.read<NotebookContextState>();
    setState(() => _isLoading = true);
    final (profile, error) = await UserDataSync.fetchUserProfile(nb.userId);
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null && profile != null) {
        final name = profile['displayName']?.toString() ?? '';
        if (name.isNotEmpty) {
          _nameController.text = name;
          nb.setUserName(name);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final nb = context.read<NotebookContextState>();
    final name = _nameController.text.trim();
    final pwd = _passwordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Save changes locally
    nb.setUserName(name);
    nb.setLearningStyle(_selectedLearningStyle);

    // Sync profile with server
    final profileErr = await UserDataSync.pushUserProfile(
      userId: nb.userId,
      displayName: name,
      password: pwd.isNotEmpty ? pwd : null,
    );

    // Sync learning style preference with server
    final quizErr = await UserDataSync.postQuizResult(
      userId: nb.userId,
      quizType: 'vark',
      learningStyle: _selectedLearningStyle,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _passwordController.clear();

      if (profileErr != null || quizErr != null) {
        final errMsgs = [
          if (profileErr != null) 'Profile: $profileErr',
          if (quizErr != null) 'Preference: $quizErr',
        ].join('\n');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally, but server sync failed:\n$errMsgs')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      }
    }
  }

  void _logout() {
    final nb = context.read<NotebookContextState>();
    nb.clearUserData();
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter your name',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'VARK Learning Style',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedLearningStyle,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _learningStyles.map((style) {
                      return DropdownMenuItem<String>(
                        value: style,
                        child: Text(style),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLearningStyle = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter new password to change',
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveChanges,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Log Out'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
