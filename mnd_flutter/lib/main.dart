import 'package:flutter/material.dart';
import 'package:mnd_flutter/screens/buses/upcoming_buses_screen.dart';
import 'package:mnd_flutter/screens/favorites/favorites_screen.dart';
import 'package:mnd_flutter/screens/home/home_screen.dart';
import 'package:mnd_flutter/screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'providers/auth_provider.dart';

void main() async {
  // First, ensure that the Flutter binding is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Then, initialize your AuthProvider. This is an async operation,
  // so we need to `await` it before running the app.
  final authProvider = AuthProvider();
  await authProvider.init();

  // Finally, run the app with the MultiProvider at the root.
  runApp(
    MultiProvider(
      providers: [
        // Use ChangeNotifierProvider.value to provide an existing notifier.
        ChangeNotifierProvider.value(value: authProvider),

        // You can add more providers here as your app grows.
        // For example, if you create a RouteProvider:
        // ChangeNotifierProvider(create: (_) => RouteProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MND - Student Bus Router',
      theme: AppTheme.lightTheme,
      // The MainScreen is now the home widget.
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // This list holds the different screens accessible from the bottom nav bar.
  final List<Widget> _screens = [
    HomeScreen(),
    UpcomingBusesScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all screens in the stack alive, preserving their state
      // as you switch between tabs.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        // `fixed` type ensures that the background of the nav bar is always visible.
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Buses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
