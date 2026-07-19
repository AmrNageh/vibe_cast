import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../services/walkie_repository.dart';
import '../../../core/widgets/neumorphic_container.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final startTime = DateTime.now();
    
    // Initialize identity
    final repo = getIt<WalkieRepository>();
    await repo.initIdentity();

    // Ensure at least 1 second of splash screen
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
    }

    if (mounted) {
      if (repo.userName != 'Unknown Node') {
        context.go('/walkie-talkie');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NeumorphicContainer(
              width: 120,
              height: 120,
              shape: BoxShape.circle,
              child: const Icon(Icons.radar, size: 60, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              'VIBECAST',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 40, letterSpacing: 4.0),
            ),
          ],
        ),
      ),
    );
  }
}
