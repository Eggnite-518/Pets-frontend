import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<SectionItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.title),
            subtitle: item.subtitle == null ? null : Text(item.subtitle!),
            trailing: const Icon(Icons.chevron_right),
            onTap: item.route == null ? null : () => context.push(item.route!),
          );
        },
      ),
    );
  }
}

class SectionItem {
  const SectionItem({
    required this.title,
    this.subtitle,
    this.route,
  });

  final String title;
  final String? subtitle;
  final String? route;
}
