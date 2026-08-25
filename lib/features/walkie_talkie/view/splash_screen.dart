import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/di/injection.dart';
import '../services/walkie_repository.dart';
import '../../../core/services/background_service_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  String _loadingText = 'INITIALIZING SYSTEM...';

  // Sawata Colors
  static const Color primary = Color(0xFF00FFCC);
  static const Color sawataBlue = Color(0xFF0F2B3E);
  static const Color backgroundDark = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();

    // 1. Entrance logo zoom & fade
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // 2. Continuous breathing pulse behind logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Typography slide & fade
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      _textController.forward();
    }

    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {
        _loadingText = 'REQUESTING PERMISSIONS...';
      });
    }

    await [
      Permission.microphone,
      Permission.notification,
    ].request();

    if (mounted) {
      setState(() {
        _loadingText = 'STARTING BACKGROUND ENGINE...';
      });
    }

    await initializeBackgroundService();
    
    final repo = getIt<WalkieRepository>();
    await repo.initIdentity();

    if (mounted) {
      setState(() {
        _loadingText = 'ENTERPRISE CAST READY';
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    try {
      if (repo.userName != 'Unknown Node') {
        context.go('/walkie-talkie');
      } else {
        context.go('/login');
      }
    } catch (_) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Obsidian & Dark Blue Cyber Ambient Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.15),
                radius: 1.2,
                colors: [
                  Color(0xFF0F2B3E), // Deep Cyber Teal & Blue center glow
                  Color(0xFF0B1B29), // Rich Obsidian Blue mid-tone
                  backgroundDark, // Deep Obsidian dark edges
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 2. Subtle Animated Radial Aura Behind Logo
          Center(
            child: AnimatedBuilder(
              animation: _pulseScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    width: math.min(size.width * 0.75, 300.0),
                    height: math.min(size.width * 0.75, 300.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          sawataBlue.withValues(alpha: 0.28), // Cyber Dark Blue glow
                          primary.withValues(alpha: 0.12), // Teal accent
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Central Brand Display
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Indomie Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _pulseScale,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseScale.value * 0.98,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 200,
                      height: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: sawataBlue.withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/indomie_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.local_dining,
                            color: Colors.white,
                            size: 80,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Animated Typography
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: SlideTransition(
                        position: _textSlide,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      const Text(
                        'SAWATA CAST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'ENTERPRISE COMM ENGINE  •  SAWATA CAST',
                          style: TextStyle(
                            color: primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Loading Indicator & Status Badge
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sleek glowing spinner
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                        backgroundColor: Colors.white12,
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.9),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Animated dynamic loading text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _loadingText,
                    key: ValueKey<String>(_loadingText),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'v1.0.0 Enterprise Release',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
