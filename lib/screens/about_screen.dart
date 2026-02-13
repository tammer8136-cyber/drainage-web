import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О приложении'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Логотип/Иконка
          const Icon(
            Icons.waves,
            size: 80,
            color: Colors.blue,
          ),
          
          const SizedBox(height: 24),
          
          // Название
          const Text(
            'Drainage Calculator',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Подзаголовок
          const Text(
            'Расчёт продольного профиля',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Версия
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Версия'),
              subtitle: const Text('3.0.0 Web'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Платформа
          Card(
            child: ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Платформа'),
              subtitle: const Text('Android, Web (PWA)'),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Автор
          Card(
            child: const ListTile(
              leading: Icon(Icons.person),
              title: Text('Автор'),
              subtitle: Text('Василевский Евгений Димитриевич'),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Дата
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Дата релиза'),
              subtitle: const Text('09 февраля 2026'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Описание
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'О приложении',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Алгоритмы, использующиеся в приложении, позволяют сделать оптимальный расчёт продольного профиля по фактическим отметкам с учётом желаемых уклонов и слоёв.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Copyright
          const Text(
            '© 2026 Василевский Евгений Димитриевич',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
