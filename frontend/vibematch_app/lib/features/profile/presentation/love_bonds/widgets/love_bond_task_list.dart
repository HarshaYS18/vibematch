import 'package:flutter/material.dart';

import '../models/love_bond_models.dart';
import 'love_bonds_background.dart';

class LoveBondTaskList extends StatelessWidget {
  const LoveBondTaskList({
    super.key,
    required this.tasks,
    required this.onTaskTap,
  });

  final List<LoveBondTaskData> tasks;
  final ValueChanged<LoveBondTaskData> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return LoveBondsGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✦ Daily Love Tasks ✦',
            style: TextStyle(
              color: Color(0xFF8B3C75),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < tasks.length; i++) ...[
            LoveBondTaskRow(task: tasks[i], onTap: () => onTaskTap(tasks[i])),
            if (i != tasks.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class LoveBondTaskRow extends StatelessWidget {
  const LoveBondTaskRow({super.key, required this.task, required this.onTap});

  final LoveBondTaskData task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD6EB), Color(0xFFFFA6D4)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(task.icon, color: const Color(0xFFFF3F9C), size: 29),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF39273F),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (task.capped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5AAA).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'CAP',
                            style: TextStyle(
                              color: Color(0xFFFF3F9C),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7A617C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: task.progress.clamp(0, 1),
                            minHeight: 7,
                            backgroundColor: const Color(0xFFEED2E3),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFF5AAA)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        task.progressLabel,
                        style: const TextStyle(
                          color: Color(0xFF7A617C),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 48, color: const Color(0xFFFFD6EB)),
            const SizedBox(width: 10),
            Column(
              children: [
                Text(
                  '+${task.reward}',
                  style: const TextStyle(
                    color: Color(0xFF3A2B45),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Affection',
                  style: TextStyle(
                    color: Color(0xFF7A617C),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB58AAA)),
          ],
        ),
      ),
    );
  }
}
