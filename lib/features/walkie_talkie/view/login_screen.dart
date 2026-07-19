import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/neumorphic_container.dart';
import '../../../core/di/injection.dart';
import '../services/walkie_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();

  void _login() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      // Pass the name to the repository so other users see this name!
      getIt<WalkieRepository>().setUserName(name);
      context.go('/walkie-talkie');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeumorphicContainer(
                width: 100,
                height: 100,
                shape: BoxShape.circle,
                child: const Icon(Icons.person_outline, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Text(
                'ENTER NODE DESIGNATION',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 24),
              NeumorphicContainer(
                borderRadius: 16,
                child: TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'e.g. ALPHA-1',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _login,
                child: NeumorphicContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: const Center(
                    child: Text(
                      'CONNECT TO NETWORK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
