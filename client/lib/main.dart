// ──────────────────────────────────────────────
// main.dart — App entry point
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/classroom_provider.dart';
import 'providers/socket_provider.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/classroom_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const RemoteClassroomApp());
}

class RemoteClassroomApp extends StatelessWidget {
  const RemoteClassroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared ApiService instance
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ClassroomProvider(apiService)),
        ChangeNotifierProvider(create: (_) => SocketProvider()),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: context.read<AuthProvider>(),
      redirect: (ctx, state) {
        final auth = ctx.read<AuthProvider>();
        final isAuth = auth.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!isAuth && !isLoginRoute) return '/login';
        if (isAuth && isLoginRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (ctx, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (ctx, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/classroom/:classId',
          builder: (ctx, state) => ClassroomScreen(
            classId: state.pathParameters['classId']!,
          ),
        ),
        GoRoute(
          path: '/dashboard/:classId',
          builder: (ctx, state) => DashboardScreen(
            classId: state.pathParameters['classId']!,
          ),
        ),
      ],
    );

    // Try auto-login on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Remote Classroom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0F0C29),
        fontFamily: 'Roboto',
      ),
      routerConfig: _router,
    );
  }
}
