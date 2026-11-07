import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value, required this.subtitle,
    required this.icon, required this.tint, required this.actions, required this.onAction});
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final List<String> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF777B75)))), Icon(icon, color: tint)]),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF777B75))),
        Align(alignment: Alignment.centerRight, child: PopupMenuButton<String>(tooltip: 'More actions', onSelected: onAction,
          itemBuilder: (_) => actions.map((a) => PopupMenuItem(value: a, child: Text(a))).toList(), child: const Icon(Icons.more_horiz))),
      ])));
}
