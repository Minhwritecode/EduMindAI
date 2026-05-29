import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'const.dart' show profileIconAsset;
import 'home_page_visual.dart';
import 'services/user_data_sync.dart';
import 'state/notebook_context_state.dart';

/// `userId` dùng cho Mongo: email (chữ thường) nếu nhập; không thì slug từ tên.
String deriveLoginUserId(String displayName, String email) {
  final em = email.trim();
  if (em.isNotEmpty) return em.toLowerCase();
  final raw = displayName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  var s = raw.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (s.isEmpty) return 'local_user';
  return s;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập tên hoặc email.')),
      );
      return;
    }
    final userId = deriveLoginUserId(name, email);
    setState(() => _busy = true);
    final err = await UserDataSync.pushUserProfile(
      userId: userId,
      displayName: name.isNotEmpty ? name : null,
      email: email.isNotEmpty ? email : null,
      password: _passwordController.text.trim().isNotEmpty ? _passwordController.text : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      final mongoDown = err.contains('503') ||
          err.toLowerCase().contains('mongo') ||
          err.toLowerCase().contains('mongo_uri');
      if (mongoDown) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa lưu được lên MongoDB (HTTP 503). Kiểm tra: file .env cùng thư mục app.py có MONGO_URI, '
              'Atlas Network Access, rồi chạy lại python app.py. Bạn vẫn vào app (chế độ cục bộ).',
            ),
            duration: Duration(seconds: 8),
          ),
        );
        context.read<NotebookContextState>().setUserId(userId);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const HomePage()),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu hồ sơ: $err')),
      );
      return;
    }
    context.read<NotebookContextState>().setUserId(userId);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              const SizedBox(height: 50),
              Image.asset(
                profileIconAsset,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.58,
              decoration: const BoxDecoration(
                color: Color(0xFFECE6E6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'LOGIN',
                      style: TextStyle(
                        color: Color(0xFF002131),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Name',
                        hintStyle: const TextStyle(color: Color(0xFF531002)),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Color(0xFF531002)),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password (optional)',
                        hintStyle: const TextStyle(color: Color(0xFF531002)),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF48A9A6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        _busy ? 'Đang đăng nhập…' : 'LOGIN',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text('Don\'t have an account?'),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/signup');
                            },
                            child: const Text(
                              'SIGN UP',
                              style: TextStyle(
                                color: Color(0xFF002131),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
