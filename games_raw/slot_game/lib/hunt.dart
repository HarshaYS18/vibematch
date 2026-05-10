import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const JackpotKingApp());
}

class JackpotKingApp extends StatelessWidget {
  const JackpotKingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jackpot King',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF130624),
        fontFamily: 'Roboto',
      ),
      home: const GameBoardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- DATA MODELS ---
class GameTarget {
  final int id;
  final String emoji;
  final int multiplier;
  final int winWeight;
  final Color themeColor;

  GameTarget(this.id, this.emoji, this.multiplier, this.winWeight, this.themeColor);
}

class BetRecord {
  final int roundId;
  final int totalBet;
  final int winnings;
  final int winningTargetId;
  final Map<int, int> betsPlaced;
  final DateTime time;

  BetRecord({required this.roundId, required this.totalBet, required this.winnings, required this.winningTargetId, required this.betsPlaced, required this.time});
}

enum GamePhase { betting, locked, rolling, revealing, result }

// --- MAIN SCREEN ---
class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({Key? key}) : super(key: key);

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> with TickerProviderStateMixin {
  int balance = 15000000;
  int countdown = 24;
  GamePhase currentPhase = GamePhase.betting;
  
  int selectedBetAmount = 400; 
  int? customBetAmount; 
  
  Map<int, int> currentBets = {}; 
  Map<int, int> previousBets = {}; 
  Map<int, int> serverBets = {}; 

  List<int> globalHistory = []; 
  List<BetRecord> personalBetHistory = []; 
  int currentRoundId = 1001;

  List<int> winningIds = [];
  int currentWinnings = 0;
  int? rollingTargetId; 
  
  Timer? gameTimer;
  final Random _random = Random();

  // LEVELING SYSTEM
  int currentLevel = 1;
  int currentXP = 0;
  int targetXP = 50000; 

  final List<GameTarget> targets = [
    GameTarget(0, '🐰', 5, 20, Colors.pinkAccent),
    GameTarget(1, '🐱', 5, 20, Colors.orangeAccent),
    GameTarget(2, '🐶', 5, 20, Colors.brown),
    GameTarget(3, '🐑', 5, 20, Colors.white),
    GameTarget(4, '🐬', 10, 8, Colors.lightBlue),
    GameTarget(5, '🐼', 15, 6, Colors.white70),
    GameTarget(6, '🦅', 25, 4, Colors.amber),
    GameTarget(7, '🦁', 45, 2, Colors.redAccent),
  ];

  @override
  void initState() {
    super.initState();
    targetXP = _random.nextInt(50000) + 50000; 
    startRound();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void startRound() {
    setState(() {
      countdown = 24;
      currentPhase = GamePhase.betting;
      currentRoundId++;
      
      if (currentBets.isNotEmpty) {
        previousBets = Map.from(currentBets);
      }
      
      currentBets.clear();
      winningIds.clear();
      currentWinnings = 0;
      rollingTargetId = null;

      serverBets.clear();
      for (var t in targets) {
        serverBets[t.id] = (_random.nextInt(100) + 10) * 1000; 
      }
    });

    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (countdown > 0) {
          countdown--;
        } else {
          timer.cancel();
          _processRoundEnd();
        }
      });
    });
  }

  String? _getDynamicHotTag(int targetId) {
    List<MapEntry<int, int>> totals = targets.map((t) {
      int total = (serverBets[t.id] ?? 0) + (currentBets[t.id] ?? 0);
      return MapEntry(t.id, total);
    }).toList();
    
    totals.sort((a, b) => b.value.compareTo(a.value));
    int rank = totals.indexWhere((e) => e.key == targetId);
    
    if (rank >= 0 && rank < 4) return 'Hot${rank + 1}';
    return null;
  }

  Future<void> _processRoundEnd() async {
    setState(() => currentPhase = GamePhase.locked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('The window for participation has ended', textAlign: TextAlign.center),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: const Duration(seconds: 2),
      ),
    );
    
    await Future.delayed(const Duration(seconds: 1));

    int finalWinnerId = _getWeightedWinner();
    winningIds = [finalWinnerId];
    
    currentWinnings = 0;
    if (currentBets.containsKey(finalWinnerId)) {
      currentWinnings = currentBets[finalWinnerId]! * targets.firstWhere((t) => t.id == finalWinnerId).multiplier;
    }

    await _startRouletteSpin(finalWinnerId);
  }

  void _addXP(int xpEarned) {
    currentXP += xpEarned;
    while (currentXP >= targetXP) {
      currentLevel++;
      currentXP -= targetXP;
      targetXP = (targetXP * 1.5).toInt() + (_random.nextInt(100000) + 50000);
    }
  }

  int _getWeightedWinner() {
    int sumOfWeights = targets.fold(0, (sum, target) => sum + target.winWeight);
    int randomWeight = _random.nextInt(sumOfWeights);
    for (var target in targets) {
      if (randomWeight < target.winWeight) return target.id;
      randomWeight -= target.winWeight;
    }
    return targets[0].id; 
  }

  Future<void> _startRouletteSpin(int finalWinnerId) async {
    setState(() => currentPhase = GamePhase.rolling);
    
    final spinPath = [0, 1, 2, 3, 7, 6, 5, 4]; 
    int minSpins = 24; 
    int winnerPathIdx = spinPath.indexOf(targets.indexWhere((t) => t.id == finalWinnerId));
    int totalSteps = minSpins + winnerPathIdx; 

    for (int i = 0; i <= totalSteps; i++) {
      if (!mounted) return;
      setState(() => rollingTargetId = targets[spinPath[i % spinPath.length]].id);
      int delayMs = 40 + (pow(i / totalSteps, 3) * 350).toInt(); 
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    
    if (!mounted) return;
    
    setState(() {
      rollingTargetId = finalWinnerId;
      currentPhase = GamePhase.revealing;
      
      globalHistory.insert(0, finalWinnerId);
      if (globalHistory.length > 10) globalHistory.removeLast();

      if (currentBets.isNotEmpty) {
        int totalBet = currentBets.values.fold(0, (sum, amount) => sum + amount);
        personalBetHistory.insert(0, BetRecord(
          roundId: currentRoundId,
          totalBet: totalBet,
          winnings: currentWinnings,
          winningTargetId: finalWinnerId,
          betsPlaced: Map.from(currentBets),
          time: DateTime.now(),
        ));
      }
      
      if (currentWinnings > 0) {
        balance += currentWinnings;
        _addXP(currentWinnings);
      }
    });
    
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => currentPhase = GamePhase.result);
    _showResultDialog();
  }

  void placeBet(int targetId) {
    if (currentPhase != GamePhase.betting || balance < selectedBetAmount) return;
    setState(() {
      balance -= selectedBetAmount; 
      currentBets[targetId] = (currentBets[targetId] ?? 0) + selectedBetAmount;
    });
  }

  void executeAutoBet() {
    if (currentPhase != GamePhase.betting) return;
    if (previousBets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous bets to repeat!', textAlign: TextAlign.center), duration: Duration(seconds: 2)),
      );
      return;
    }

    int totalNeeded = previousBets.values.fold(0, (sum, amt) => sum + amt);
    
    if (balance >= totalNeeded) {
      setState(() {
        balance -= totalNeeded;
        previousBets.forEach((targetId, amount) {
          currentBets[targetId] = (currentBets[targetId] ?? 0) + amount;
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto Bets Placed!', textAlign: TextAlign.center), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance for Auto Bet!', textAlign: TextAlign.center), duration: Duration(seconds: 2)),
      );
    }
  }

  void _showResultDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true, 
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ResultOverlay(winnings: currentWinnings, onClose: () => Navigator.pop(context));
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(scale: Curves.easeOutBack.transform(anim1.value), child: Opacity(opacity: anim1.value, child: child));
      },
    ).then((_) {
      if (mounted && currentPhase == GamePhase.result) startRound();
    });
    
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && currentPhase == GamePhase.result) Navigator.pop(context);
    });
  }

  void _showPersonalHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1B0B3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          border: Border(top: BorderSide(color: Colors.amberAccent, width: 2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("My Bet History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: personalBetHistory.isEmpty
                  ? const Center(child: Text("No bets placed yet.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: personalBetHistory.length,
                      itemBuilder: (context, index) {
                        final record = personalBetHistory[index];
                        final winningTarget = targets.firstWhere((t) => t.id == record.winningTargetId);
                        bool isWin = record.winnings > 0;
                        int profit = record.winnings - record.totalBet;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF281452),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isWin ? Colors.green.withOpacity(0.5) : Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Round #${record.roundId}", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                  Text(
                                    isWin ? "+$profit 💎" : "$profit 💎",
                                    style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 20),
                              Row(
                                children: [
                                  const Text("Winner: ", style: TextStyle(color: Colors.white70)),
                                  Text("${winningTarget.emoji} ${winningTarget.multiplier}x", style: const TextStyle(fontSize: 18)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text("Your Bets:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: record.betsPlaced.entries.map((e) {
                                  final t = targets.firstWhere((tgt) => tgt.id == e.key);
                                  bool betWon = e.key == record.winningTargetId;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: betWon ? Colors.amber.withOpacity(0.2) : Colors.black26,
                                      border: Border.all(color: betWon ? Colors.amber : Colors.transparent),
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text("${t.emoji} ${e.value}", style: TextStyle(color: betWon ? Colors.amberAccent : Colors.white70, fontSize: 12)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomKeyboard() {
    String tempInput = customBetAmount?.toString() ?? "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void append(String val) { if (tempInput.length < 9) setModalState(() => tempInput += val); }
          void backspace() { if (tempInput.isNotEmpty) setModalState(() => tempInput = tempInput.substring(0, tempInput.length - 1)); }
          void confirm() {
            if (tempInput.isNotEmpty) {
              int parsed = int.tryParse(tempInput) ?? 0;
              if (parsed > 0) setState(() { customBetAmount = parsed; selectedBetAmount = parsed; });
            }
            Navigator.pop(context);
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.45,
            padding: const EdgeInsets.only(bottom: 20, top: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B0B3B), borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5), width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(color: const Color(0xFF130624), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.diamond, color: Colors.amberAccent, size: 28),
                      Text(tempInput.isEmpty ? "0" : tempInput.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, childAspectRatio: 2.2, mainAxisSpacing: 8, crossAxisSpacing: 8,
                          children: [
                            _calcBtn('7', () => append('7')), _calcBtn('8', () => append('8')), _calcBtn('9', () => append('9')),
                            _calcBtn('4', () => append('4')), _calcBtn('5', () => append('5')), _calcBtn('6', () => append('6')),
                            _calcBtn('1', () => append('1')), _calcBtn('2', () => append('2')), _calcBtn('3', () => append('3')),
                            _calcBtn('0', () => append('0')), _calcBtn('00', () => append('00')), _calcBtn('000', () => append('000')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Expanded(child: _calcIconBtn(Icons.backspace_outlined, backspace, const Color(0xFF4C2A85))), const SizedBox(height: 8),
                            Expanded(child: _calcIconBtn(Icons.keyboard_hide, () => Navigator.pop(context), const Color(0xFF4C2A85))), const SizedBox(height: 8),
                            Expanded(flex: 2, child: _calcIconBtn(Icons.check_circle, confirm, Colors.blueAccent)),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _calcBtn(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(decoration: BoxDecoration(color: const Color(0xFF2D165D), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)))),
    );
  }

  Widget _calcIconBtn(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Center(child: Icon(icon, color: Colors.white, size: 28))),
    );
  }

  void _showLevelProgress() {
    showDialog(
      context: context,
      builder: (context) {
        double progress = currentXP / targetXP;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A148C), Color(0xFF1B0B3B)]),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amberAccent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_purple500, size: 50, color: Colors.amber), const SizedBox(height: 10),
                Text("Level $currentLevel", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 25),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: progress, minHeight: 15, backgroundColor: Colors.black45, valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent)),
                ),
                const SizedBox(height: 15),
                Text("${currentXP.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} / ${targetXP.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} 💎", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: () => Navigator.pop(context),
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12), child: Text("Continue", style: TextStyle(fontWeight: FontWeight.bold))),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.5, colors: [Color(0xFF381A66), Color(0xFF130624)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopNav(),
              _buildPlayerStats(),
              _buildHistoryBar(), 
              _buildTimerPill(),
              const SizedBox(height: 5),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;
                    double height = constraints.maxHeight;
                    double ratio = ((width - 48) / 4) / ((height - 24) / 2); 

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, childAspectRatio: ratio > 0.85 ? 0.85 : ratio, crossAxisSpacing: 8, mainAxisSpacing: 12,
                      ),
                      itemCount: targets.length,
                      itemBuilder: (context, index) {
                        final target = targets[index];
                        return AnimatedTargetCard(
                          target: target,
                          betAmount: currentBets[target.id],
                          isWinner: winningIds.contains(target.id),
                          isRollingFocus: rollingTargetId == target.id,
                          phase: currentPhase,
                          hotTag: _getDynamicHotTag(target.id),
                          onTap: () => placeBet(target.id),
                        );
                      },
                    );
                  }
                ),
              ),
              _buildConversionRate(),
              _buildControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('JACKPOT KING', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 1.5)),
                  Text('developed by Harsha', style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 0.5, fontStyle: FontStyle.italic)),
                ],
              ),
            ],
          ),
          Row(
            children: const [
              Icon(Icons.help_outline, color: Colors.white60, size: 22), SizedBox(width: 16),
              Icon(Icons.aspect_ratio, color: Colors.white60, size: 22), SizedBox(width: 16),
              Icon(Icons.close, color: Colors.white60, size: 24),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPlayerStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showLevelProgress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF6B3CE2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amberAccent, width: 1)),
              child: Text('Lv$currentLevel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _showPersonalHistory, 
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                  gradient: const LinearGradient(colors: [Color(0xFFD35400), Color(0xFFE67E22)]),
                ),
                child: Row(
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: CircleAvatar(radius: 10, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 14, color: Colors.white))),
                    Expanded(
                      child: Text(
                        '💎 ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}  (History ⬇)',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
        ],
      ),
    );
  }

  Widget _buildHistoryBar() {
    if (globalHistory.isEmpty) return const SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Text("Recent: ", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: SizedBox(
              height: 25,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: globalHistory.length,
                itemBuilder: (context, index) {
                  final target = targets.firstWhere((t) => t.id == globalHistory[index]);
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.amber.withOpacity(0.3) : Colors.black38,
                      border: Border.all(color: index == 0 ? Colors.amber : Colors.white24),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Center(child: Text(target.emoji, style: const TextStyle(fontSize: 14))),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimerPill() {
    bool isAlert = currentPhase != GamePhase.betting;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D165D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAlert ? Colors.redAccent : const Color(0xFF8E44AD), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isAlert ? 'Calculating >>' : 'Remaining  >>', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 12),
          Text(countdown.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isAlert ? Colors.redAccent : Colors.amberAccent, letterSpacing: 1.2)),
          const SizedBox(width: 12),
          const Text('<<', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildConversionRate() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
        child: const Text('1 💎 = 200 ✨', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.only(bottom: 30, top: 16, left: 12, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B0B3B), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('Auto', const Color(0xFF4A90E2), executeAutoBet),
          _buildBetChip(400, '400', Colors.amber),
          _buildBetChip(10000, '10K', Colors.lightBlueAccent),
          _buildBetChip(100000, '100K', Colors.purpleAccent),
          _buildCustomAmountButton(),
        ],
      ),
    );
  }

  Widget _buildBetChip(int amount, String label, Color glowColor) {
    bool isSelected = selectedBetAmount == amount;
    return GestureDetector(
      onTap: () => setState(() => selectedBetAmount = amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), height: isSelected ? 65 : 55, width: isSelected ? 65 : 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: isSelected ? [glowColor.withOpacity(0.8), glowColor] : [const Color(0xFF34495E), const Color(0xFF2C3E50)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 15, spreadRadius: 2)] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.diamond, size: isSelected ? 20 : 16, color: isSelected ? Colors.white : glowColor),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: isSelected ? 14 : 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAmountButton() {
    bool isSelected = customBetAmount != null && selectedBetAmount == customBetAmount;
    String label = customBetAmount == null ? 'Customized\nAmount' : (customBetAmount! >= 1000 ? '${(customBetAmount! / 1000).toStringAsFixed(0)}K' : customBetAmount.toString());

    return GestureDetector(
      onTap: () {
        if (customBetAmount != null && !isSelected) {
          setState(() => selectedBetAmount = customBetAmount!);
        } else {
          _showCustomKeyboard();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), height: isSelected ? 65 : 55, width: isSelected ? 75 : 70, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : const Color(0xFF4A90E2), borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 15, spreadRadius: 2)] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customBetAmount != null) Icon(Icons.diamond, size: isSelected ? 16 : 14, color: Colors.white),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: customBetAmount == null ? 11 : (isSelected ? 14 : 12), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(25)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- TARGET CARD ---
class AnimatedTargetCard extends StatefulWidget {
  final GameTarget target;
  final int? betAmount;
  final bool isWinner;
  final bool isRollingFocus;
  final GamePhase phase;
  final String? hotTag; 
  final VoidCallback onTap;

  const AnimatedTargetCard({Key? key, required this.target, required this.betAmount, required this.isWinner, required this.isRollingFocus, required this.phase, required this.hotTag, required this.onTap}) : super(key: key);

  @override
  State<AnimatedTargetCard> createState() => _AnimatedTargetCardState();
}

class _AnimatedTargetCardState extends State<AnimatedTargetCard> with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _winPulseController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _winPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(AnimatedTargetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWinner && widget.phase == GamePhase.revealing && oldWidget.phase != GamePhase.revealing) {
      _winPulseController.repeat(reverse: true);
    } else if (widget.phase == GamePhase.betting) {
      _winPulseController.reset();
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _winPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasBet = widget.betAmount != null;
    bool showWinningEffect = widget.isWinner && (widget.phase == GamePhase.revealing || widget.phase == GamePhase.result);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breatheController, _winPulseController]),
        builder: (context, child) {
          Color borderColor = widget.isRollingFocus ? Colors.white : (showWinningEffect ? Colors.amberAccent : (hasBet ? widget.target.themeColor : const Color(0xFF7D4CDb).withOpacity(0.5 + (_breatheController.value * 0.5))));
          double borderWidth = widget.isRollingFocus ? 4.0 : (showWinningEffect ? 4.0 : (hasBet ? 3.0 : 2.0));
          double scale = showWinningEffect ? 1.05 + (_winPulseController.value * 0.05) : (widget.isRollingFocus ? 1.1 : 1.0);

          return Transform.scale(
            scale: scale,
            child: Container(
              padding: EdgeInsets.all(borderWidth),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: widget.isRollingFocus || showWinningEffect ? [borderColor.withOpacity(0.9), Colors.white, borderColor.withOpacity(0.9)] : [borderColor, borderColor.withOpacity(0.3), borderColor],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: widget.isRollingFocus || showWinningEffect ? [BoxShadow(color: borderColor.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)] : [],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18 - borderWidth),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: showWinningEffect ? [Colors.orange.shade800, Colors.amber.shade600] : (widget.isRollingFocus ? [Colors.lightBlueAccent.shade400, Colors.blue.shade900] : [const Color(0xFF4C2A85), const Color(0xFF281452)]),
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Added dropshadow to the emoji to make it pop like a 3D asset
                  Text(
                    widget.target.emoji, 
                    style: const TextStyle(fontSize: 48, shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))])
                  ), 
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF1B0B3B), borderRadius: BorderRadius.circular(12)),
                    child: Text('1:${widget.target.multiplier}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            if (widget.hotTag != null)
              Positioned(
                top: -1, left: -1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFF09819)]), borderRadius: BorderRadius.only(topLeft: Radius.circular(15), bottomRight: Radius.circular(10)),
                  ),
                  child: Text(widget.hotTag!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            if (hasBet)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 300), curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amberAccent, width: 2), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diamond, size: 14, color: Colors.amberAccent), const SizedBox(width: 6),
                            Text(widget.betAmount! >= 1000 ? '${(widget.betAmount!/1000).toStringAsFixed(0)}K' : widget.betAmount.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

// --- RESULT OVERLAY ---
class ResultOverlay extends StatelessWidget {
  final int winnings;
  final VoidCallback onClose;

  const ResultOverlay({Key? key, required this.winnings, required this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool didWin = winnings > 0;
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5B247A), Color(0xFF1B0B3B)]),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: didWin ? Colors.amber : const Color(0xFF8E44AD), width: 3),
              boxShadow: [BoxShadow(color: (didWin ? Colors.amber : Colors.deepPurple).withOpacity(0.6), blurRadius: 40, spreadRadius: 5)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(didWin ? "You got Diamond rewards!" : "Sorry, you didn't win a prize", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (didWin) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 30, spreadRadius: 10)])),
                      const Icon(Icons.shopping_bag, color: Colors.amber, size: 80),
                      const Positioned(bottom: 0, child: Icon(Icons.star, color: Colors.white, size: 24)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('x${winnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', style: const TextStyle(color: Colors.amberAccent, fontSize: 36, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
                ],
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                  child: const Text("Big winners in this round", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildWinnerAvatar("Kavish", 250000, 2, const Color(0xFFC0C0C0), 'https://i.pravatar.cc/150?img=11'),
                    _buildWinnerAvatar("Ranveer", 600000, 1, const Color(0xFFFFD700), 'https://i.pravatar.cc/150?img=33'),
                    _buildWinnerAvatar("Destroyer", 75000, 3, const Color(0xFFCD7F32), 'https://i.pravatar.cc/150?img=68'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerAvatar(String name, int amount, int rank, Color crownColor, String imageUrl) {
    double size = rank == 1 ? 85 : 65;
    return Column(
      children: [
        Icon(Icons.military_tech, color: crownColor, size: rank == 1 ? 45 : 35),
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: crownColor, width: 3),
            boxShadow: [BoxShadow(color: crownColor.withOpacity(0.5), blurRadius: 10)],
            image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(Icons.diamond, size: 12, color: Colors.blue.shade300), const SizedBox(width: 4),
              Text(amount >= 1000 ? '${(amount/1000).toStringAsFixed(0)}K' : amount.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }
}