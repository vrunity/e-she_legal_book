import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importing Provider package
import 'Signup_Page.dart'; // Importing Signup Page correctly.
import 'loginpage.dart';
import 'UserListPage.dart'; // Adjusted import to match standard practice.
import 'PdfListPage.dart';

// ThemeProvider for managing light/dark mode
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Flutter MySQL App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/userListPage': (context) => UserListPage(),
        '/userHomePage': (context) => LoginPage(),
        '/pdfListPage': (context) => PdfListPage(isApproved: true),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
