import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class MiniProfileReportSheet extends StatefulWidget {
  const MiniProfileReportSheet({super.key, required this.user});

  final SeatUser user;

  @override
  State<MiniProfileReportSheet> createState() => _MiniProfileReportSheetState();
}

class _MiniProfileReportSheetState extends State<MiniProfileReportSheet> {
  final List<String> _reasons = const [
    'Harassment or bullying',
    'Hate or abusive speech',
    'Scam or fraud',
    'Sexual or inappropriate content',
    'Spam or fake profile',
    'Other safety issue',
  ];

  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.report_gmailerrorred_rounded,
                  color: RoomColors.coral,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report ${widget.user.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Select a reason. This will later create a safety report for CS/Monitor review.',
                      style: TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: _selectedReason == reason
                        ? RoomColors.coral.withValues(alpha: 0.10)
                        : RoomColors.pearl,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedReason == reason
                          ? RoomColors.coral.withValues(alpha: 0.35)
                          : RoomColors.softLine,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedReason == reason
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: _selectedReason == reason
                            ? RoomColors.coral
                            : const Color(0xFF9A8FA3),
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            color: RoomColors.plum,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason == null ? null : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: RoomColors.coral,
                foregroundColor: Colors.white,
                disabledBackgroundColor: RoomColors.softLine,
                disabledForegroundColor: const Color(0xFF9A8FA3),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Submit Report',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
