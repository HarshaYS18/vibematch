import 'package:flutter/material.dart';

class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Rankings load from backend /rankings APIs only.'),
      ),
    );
  }
}
