import 'package:flutter/material.dart';
import 'package:drainage_app/theme/app_theme.dart';
import 'package:drainage_app/screens/projects_list_screen.dart';
import 'package:drainage_app/repositories/repository_factory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация репозитория (автоматически выбирает SQLite или localStorage)
  await RepositoryFactory.getInstance();
  
  runApp(const DrainageApp());
}

class DrainageApp extends StatelessWidget {
  const DrainageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drainage Calculator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const ProjectsListScreen(),
    );
  }
}
