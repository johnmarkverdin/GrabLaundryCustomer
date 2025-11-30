import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'pages/auth_customer_page.dart';
import 'pages/customer_home_page.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const CustomerApp());
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({Key? key}) : super(key: key);

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  bool _checkingSession = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();

    // Listen for auth changes (same pattern as Admin / Rider)
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      setState(() {
        _loggedIn = event.session != null;
      });
    });
  }

  void _checkSession() {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _loggedIn = session != null;
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      // While we’re still checking Supabase session
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'GrabLaundry Customer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        useMaterial3: true,
      ),
      // ✅ if logged in -> CustomerHomePage, else -> CustomerAuthPage
      home: AnimatedSplashScreen(
        nextScreen: _loggedIn
            ? const CustomerHomePage()
            : const CustomerAuthPage(),
      ),
    );
  }
}
