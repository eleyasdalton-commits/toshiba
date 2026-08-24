import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(TaskHabitApp(themeProvider: themeProvider));
}

class TaskHabitApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const TaskHabitApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Task & Habit Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}
