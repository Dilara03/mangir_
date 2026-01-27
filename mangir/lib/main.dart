import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/forgot_password_screen.dart';

void main() {
  runApp(const MangirApp());
}

class MangirApp extends StatelessWidget {
  const MangirApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mangır',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF5B8DEF),
        scaffoldBackgroundColor: const Color(0xFFF8FAFB),
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B8DEF)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const DashboardScreen(),
        '/add_transaction': (context) => const AddTransactionScreen(),
        '/statistics': (context) => const StatisticsScreen(),
        '/transactions': (context) => const TransactionsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}
