import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/walkie_talkie/view/walkie_talkie_screen.dart';
import '../../features/walkie_talkie/view/walkie_channel_screen.dart';
import '../../features/walkie_talkie/view/group_create_screen.dart';

import '../../features/walkie_talkie/view/splash_screen.dart';
import '../../features/walkie_talkie/view/login_screen.dart';
import '../../features/walkie_talkie/models/walkie_group_entity.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/walkie-talkie',
      builder: (context, state) => const WalkieTalkieScreen(),
      routes: [
        GoRoute(
          path: 'channel',
          builder: (context, state) {
            final group = state.extra as WalkieGroupEntity;
            return WalkieChannelScreen(group: group);
          },
        ),
        GoRoute(
          path: 'create-group',
          builder: (context, state) => const GroupCreateScreen(),
        ),
      ],
    ),
  ],
);
