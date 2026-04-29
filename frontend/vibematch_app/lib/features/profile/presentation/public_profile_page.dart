import 'package:flutter/material.dart';

class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({
    super.key,
    this.userId = '6418000000',
    this.displayName = 'Vibe User',
    this.username,
  });

  final String userId;
  final String displayName;
  final String? username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFECE2D8)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6), Color(0xFFE84C72)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'V',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    username == null ? 'ID $userId' : '@$username · ID $userId',
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Public profile route skeleton. Later this page will show avatar frame, VIP/SVIP, family, relationship, vibes, bio, gifts received, followers, and privacy-aware presence.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4A2A63),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
