import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/gemini_service.dart';
import 'services/history_service.dart';
import 'services/native_bridge_service.dart';
import 'services/reply_engine.dart';
import 'services/storage_service.dart';
import 'utils/theme.dart';
import 'screens/business_profile_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tester_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReplyGeniusApp());
}

class ReplyGeniusApp extends StatelessWidget {
  const ReplyGeniusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<NativeBridgeService>(create: (_) => NativeBridgeService()),
        Provider<HistoryService>(create: (_) => HistoryService()),
        ChangeNotifierProvider<ReplyEngine>(
          create: (ctx) => ReplyEngine(
            storage: ctx.read<StorageService>(),
            bridge: ctx.read<NativeBridgeService>(),
            history: ctx.read<HistoryService>(),
            gemini: GeminiService(''),
          )..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'ReplyGenius',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _StartupGate(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/profile': (_) => const BusinessProfileScreen(),
          '/faq': (_) => const FaqScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/history': (_) => const HistoryScreen(),
          '/tester': (_) => const TesterScreen(),
        },
      ),
    );
  }
}

/// Decides whether to show onboarding or home based on persisted state.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final storage = context.read<StorageService>();
    final done = await storage.isOnboardingDone();
    if (!mounted) return;
    setState(() => _onboarded = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_onboarded == false) {
      // OnboardingScreen calls markOnboardingDone() then navigates to /home.
      return const OnboardingScreen();
    }
    return const HomeScreen();
  }
}
