import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'pages/auth_customer_page.dart';
import 'pages/customer_home_page.dart';

void main() async {
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

    // Listen for auth changes
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      setState(() {
        _loggedIn = session != null;
      });
    });
  }

  Future<void> _checkSession() async {
    final session = supabase.auth.currentSession;
    setState(() {
      _loggedIn = session != null;
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'GrabLaundry Customer',
      theme: ThemeData(primarySwatch: Colors.blue),

      // ✅ Correct: show Auth when NOT logged in, Home when logged in
      home: _loggedIn
          ? const CustomerAuthPage()
          : const CustomerHomePage(),
    );
  }
}
