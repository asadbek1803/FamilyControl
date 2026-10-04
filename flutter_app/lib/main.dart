import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/notification_settings_provider.dart';
import 'core/constants/api_constants.dart';
import 'core/network/native_bridge.dart';
import 'core/network/remote_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/child/child_home_screen.dart';
import 'screens/child/pin_lock_screen.dart';

/// AccessibilityService ilovani to'g'ridan-to'g'ri ishga tushirganda (ilova
/// jarayoni o'ldirilgan holatda ham bo'ladi) `pinLockRequested` keladi.
/// `navigatorKey` orqali route'ni xabar berish mumkin bo'ladi.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const MethodChannel nativeChannel = MethodChannel('com.familycontrol/accessibility');

/// `/pin_lock` allaqachon ochilgan bo'lsa, yana ochilmaydi. Aks holda har bir
/// `TYPE_WINDOW_STATE_CHANGED` hodisasi yangi ekran yig'adi.
bool _isPinLockOpen = false;

Future<void> openPinLock() async {
  if (_isPinLockOpen) return;
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  _isPinLockOpen = true;
  try {
    await navigator.pushNamed('/pin_lock');
  } finally {
    _isPinLockOpen = false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ilova qayta ishga tushganda (cold start) `require_pin` intent bayrog'i
  // o'qilgan bo'lishi mumkin — uni shu yerda olib olamiz.
  nativeChannel.setMethodCallHandler((call) async {
    if (call.method == 'pinLockRequested') {
      await openPinLock();
    }
    return null;
  });

  // Server manzili GitHub'dan yangilanadi (imzosiz fayl — batafsil
  // `RemoteConfig` hujjatida). Eski mexanizm — Telegram orqali URL yuborish —
  // butunlay olib tashlangan: u bot tokeni APK ichida oshkor bo'lgani uchun
  // barcha qurilmalarni hujumchi serveriga yo'naltirish imkonini berardi.
  //
  // `resolveBaseUrl` hech qachon istalnomagan holatda `defaultBaseUrl` ga
  // qaytadi — ilova GitHub ishlamagan taqdirda ham ishlayveradi.
  ApiConstants.baseUrl = await RemoteConfig.resolveBaseUrl(
    ApiConstants.defaultBaseUrl,
  );

  // Native qismlar (`AdminReceiver`, `ChildAccessibilityService`) ham hodisa
  // yuborishi uchun server manzilini bilishi kerak — ular Dart'siz ishlaydi.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NativeBridge.syncServerBaseUrl();
  });

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
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),
      ],
      child: MaterialApp(
        title: 'FamilyControl',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
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
                borderRadius: BorderRadius.all(Radius.circular(10)),
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
    final isChildMode = prefs.getBool('is_child_mode');

    if (!mounted) return;
    setState(() {
      _isChildMode = isChildMode;
      _isLoading = false;
    });

    // Cold start: MainActivity `require_pin` ni intent'dan o'qib bayroqqa
    // solgan bo'lishi mumkin (onNewIntent ishga tushmagan holat).
    if (isChildMode == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final required = await nativeChannel
            .invokeMethod<bool>('consumePinRoute')
            .catchError((_) => false);
        if (required == true && mounted) {
          await openPinLock();
        }
      });
    }
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
