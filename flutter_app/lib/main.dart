import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/api_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/connectivity_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/child/child_home_screen.dart';
import 'screens/child/pin_lock_screen.dart';

void main() async {
  // Flutter binding tayyorlanishini kutish
  WidgetsFlutterBinding.ensureInitialized();

  // Telegram bot orqali kelgan dinamik URL bo'lsa uni yuklab olish
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('dynamic_base_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    ApiConstants.baseUrl = savedUrl;
  }

  runApp(const FamilyControlApp());
}

class FamilyControlApp extends StatelessWidget {
  const FamilyControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        title: 'FamilyControl',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A90D9),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        routes: {
          '/pin_lock': (context) => const PinLockScreen(),
        },
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isChildMode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkMode();
  }

  Future<void> _checkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isChildMode = prefs.getBool('is_child_mode');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isChildMode == null) {
      return const RoleSelectionScreen();
    }

    if (_isChildMode == true) {
      return const ChildHomeScreen();
    }

    // Ota-ona rejimi
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
