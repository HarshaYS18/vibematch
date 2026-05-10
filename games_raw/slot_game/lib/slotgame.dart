import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const ChatRoomApp());
}

// --- DUMMY CHAT ROOM APP ---
class ChatRoomApp extends StatelessWidget {
  const ChatRoomApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jackpot King Chat',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        fontFamily: 'Roboto',
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- CHAT SCREEN WITH DRAGGABLE OVERLAY ---
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isGameVisible = false;
  double _overlayYOffset = 100.0; 

  void _toggleGame() {
    setState(() {
      _isGameVisible = !_isGameVisible;
      if (_isGameVisible) {
        _overlayYOffset = MediaQuery.of(context).size.height * 0.05; 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final overlayHeight = screenHeight * 0.60; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. THE CHAT UI
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildChatBubble('Player1', 'Anyone want to play a round?', true),
                    _buildChatBubble('You', 'Let\'s go! I am opening the game now.', false),
                    _buildChatBubble('System', 'Click the gold controller icon below to launch the overlay.', true),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF1A1A1A),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: const Text('Type a message...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _toggleGame,
                      child: Container(
                        height: 40, width: 40,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.amber, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.gamepad, color: Colors.black87, size: 20),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),

          // 2. THE DRAGGABLE GAME OVERLAY
          if (_isGameVisible)
            Positioned(
              top: _overlayYOffset,
              left: 6,
              right: 6,
              child: Material(
                elevation: 24,
                color: Colors.transparent,
                child: Container(
                  height: overlayHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF130624),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amberAccent, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.9), blurRadius: 25, spreadRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      // --- DRAGGABLE HEADER ---
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF281452),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _overlayYOffset += details.delta.dy;
                                  if (_overlayYOffset < 0) _overlayYOffset = 0;
                                  if (_overlayYOffset > screenHeight - overlayHeight - 60) {
                                    _overlayYOffset = screenHeight - overlayHeight - 60;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                color: Colors.transparent, 
                                child: const Icon(Icons.drag_indicator, color: Colors.amberAccent, size: 22),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('JACKPOT KING', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                                Text('developed by Harsha', style: TextStyle(color: Colors.white70, fontSize: 8, fontStyle: FontStyle.italic)),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _toggleGame,
                            ),
                          ],
                        ),
                      ),
                      // --- THE GAME CONTENT ---
                      const Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                          child: GameBoardScreen(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String sender, String text, bool isLeft) {
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isLeft ? Colors.white12 : Colors.deepPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender, style: TextStyle(fontSize: 9, color: isLeft ? Colors.amber : Colors.white70)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ========================= JACKPOT KING GAME CODE ===========================
// ============================================================================

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

class GlobalResult {
  final int targetId;
  final DateTime time;
  GlobalResult({required this.targetId, required this.time});
}

enum GamePhase { betting, locked, rolling, revealing, result }

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

  List<GlobalResult> globalHistory = []; 
  List<BetRecord> personalBetHistory = []; 
  int currentRoundId = 1001;

  List<int> winningIds = [];
  int currentWinnings = 0;
  int? rollingTargetId; 
  
  Timer? gameTimer;
  final Random _random = Random();

  int currentLevel = 1;
  int currentXP = 0;
  int targetXP = 50000; 

  // INLINE OVERLAY STATES
  bool _showKeypadOverlay = false;
  bool _showHistoryOverlay = false; // Personal
  bool _showGlobalHistoryOverlay = false; // Global
  bool _showLevelOverlay = false;
  bool _showResultOverlay = false;
  String _keypadInput = "";

  // CUSTOM IN-GAME TOAST SYSTEM
  bool _showToast = false;
  String _toastMessage = "";
  Color _toastColor = Colors.black87;
  Timer? _toastTimer;

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
    _toastTimer?.cancel();
    super.dispose();
  }

  void _triggerToast(String message, {Color color = Colors.black87}) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastColor = color;
      _showToast = true;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showToast = false);
    });
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

      // Realistic server bets (Low amounts so user bets actually impact Hot Tags)
      serverBets.clear();
      for (var t in targets) {
        serverBets[t.id] = (t.winWeight * 100) + _random.nextInt(500); 
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
    setState(() {
      currentPhase = GamePhase.locked;
      _showKeypadOverlay = false;
      _showHistoryOverlay = false;
      _showGlobalHistoryOverlay = false;
      _showLevelOverlay = false;
    });
    
    _triggerToast("Betting Closed 🛑");
    
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
      
      // Update Global History (Stores up to 50 for the 📄 ledger)
      globalHistory.insert(0, GlobalResult(targetId: finalWinnerId, time: DateTime.now()));
      if (globalHistory.length > 50) globalHistory.removeLast();

      if (currentBets.isNotEmpty) {
        int totalBet = currentBets.values.fold(0, (sum, amount) => sum + amount);
        personalBetHistory.insert(0, BetRecord(
          roundId: currentRoundId, totalBet: totalBet, winnings: currentWinnings, winningTargetId: finalWinnerId, betsPlaced: Map.from(currentBets), time: DateTime.now(),
        ));
      }
      
      if (currentWinnings > 0) {
        balance += currentWinnings;
        _addXP(currentWinnings);
      }
    });
    
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    setState(() {
      currentPhase = GamePhase.result;
      _showResultOverlay = true; 
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showResultOverlay) _closeResultOverlay();
    });
  }

  void _closeResultOverlay() {
    setState(() => _showResultOverlay = false);
    startRound(); 
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
      _triggerToast("No previous bets to repeat! ❌");
      return;
    }

    int totalNeeded = previousBets.values.fold(0, (sum, amt) => sum + amt);
    
    if (balance >= totalNeeded) {
      setState(() {
        balance -= totalNeeded;
        previousBets.forEach((targetId, amount) { currentBets[targetId] = (currentBets[targetId] ?? 0) + amount; });
      });
      _triggerToast("Auto Bets Placed! ✅", color: Colors.green.shade800);
    } else {
      _triggerToast("Insufficient balance! ⚠️", color: Colors.red.shade900);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- BASE GAME BOARD ---
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment.topCenter, radius: 1.5, colors: [Color(0xFF381A66), Color(0xFF130624)]),
          ),
          child: Column( 
            children: [
              _buildPlayerStats(),
              _buildHistoryBar(), 
              _buildTimerPill(),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double hPadding = 12.0; 
                    double spacing = 8.0;
                    double width = constraints.maxWidth - (hPadding * 2);
                    double height = constraints.maxHeight;
                    double itemWidth = (width - (spacing * 3)) / 4; 
                    double itemHeight = (height - spacing) / 2; 
                    double ratio = itemWidth / itemHeight; 

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), 
                      padding: EdgeInsets.symmetric(horizontal: hPadding),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, childAspectRatio: ratio, crossAxisSpacing: spacing, mainAxisSpacing: spacing,
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
              _buildControlPanel(),
            ],
          ),
        ),

        // --- IN-GAME TOAST NOTIFICATION ---
        if (_showToast)
          Positioned(
            bottom: 80, 
            left: 20, right: 20,
            child: AnimatedOpacity(
              opacity: _showToast ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: _toastColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(_toastMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),

        // --- INLINE MENUS ---
        if (_showKeypadOverlay) _buildInlineKeypad(),
        if (_showHistoryOverlay) _buildInlineHistory(),
        if (_showGlobalHistoryOverlay) _buildInlineGlobalHistory(),
        if (_showLevelOverlay) _buildInlineLevelProgress(),
        if (_showResultOverlay) _buildInlineResult(),
      ],
    );
  }

  // =======================================================================
  // INLINE COMPONENT BUILDERS
  // =======================================================================

  Widget _buildPlayerStats() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
      child: Row(
        children: [
          // LEVEL INDICATOR
          GestureDetector(
            onTap: () => setState(() => _showLevelOverlay = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF6B3CE2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amberAccent, width: 1)),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 10, color: Colors.amberAccent),
                  const SizedBox(width: 2),
                  Text('Lv$currentLevel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.amberAccent)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // COMPACT DIAMOND PILL (SHRINK-WRAPPED)
          GestureDetector(
            onTap: () => setState(() => _showHistoryOverlay = true), 
            child: Container(
              height: 24,
              padding: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amberAccent, width: 1),
                gradient: const LinearGradient(colors: [Color(0xFFD35400), Color(0xFFE67E22)]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Forces it to be small
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6.0), child: CircleAvatar(radius: 6, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 8, color: Colors.white))),
                  Text(
                    '💎 ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(), // Pushes clock and giftcard to the right edge
          // CLOCK ICON FOR PERSONAL HISTORY
          GestureDetector(
            onTap: () => setState(() => _showHistoryOverlay = true), 
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF281452), 
                borderRadius: BorderRadius.circular(8), 
                border: Border.all(color: Colors.amberAccent, width: 1)
              ),
              child: const Icon(Icons.history, color: Colors.amberAccent, size: 14),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.card_giftcard, color: Colors.amber, size: 20),
        ],
      ),
    );
  }

  Widget _buildHistoryBar() {
    List<GlobalResult> recent5 = globalHistory.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Row(
        children: [
          const Text("Recent:", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                // Render up to 5 recent Emojis
                ...recent5.asMap().entries.map((entry) {
                  int index = entry.key;
                  GlobalResult res = entry.value;
                  final target = targets.firstWhere((t) => t.id == res.targetId);
                  return Container(
                    margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.amber.withOpacity(0.3) : Colors.black38,
                      border: Border.all(color: index == 0 ? Colors.amber : Colors.white24, width: 0.5), borderRadius: BorderRadius.circular(4)
                    ),
                    child: Center(child: Text(target.emoji, style: const TextStyle(fontSize: 10))),
                  );
                }).toList(),
                const Spacer(),
                // 📄 PAPER EMOJI TO OPEN GLOBAL HISTORY
                GestureDetector(
                  onTap: () => setState(() => _showGlobalHistoryOverlay = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      border: Border.all(color: Colors.amberAccent, width: 1), borderRadius: BorderRadius.circular(4)
                    ),
                    child: const Text("📄", style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimerPill() {
    bool isAlert = currentPhase != GamePhase.betting;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2D165D), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAlert ? Colors.redAccent : const Color(0xFF8E44AD), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isAlert ? '⏳ Calc' : '⏳ Remain', style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 8),
          Text(countdown.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isAlert ? Colors.redAccent : Colors.amberAccent, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 12, left: 6, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B0B3B), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('🤖 Auto', const Color(0xFF4A90E2), executeAutoBet),
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
        duration: const Duration(milliseconds: 200), height: isSelected ? 48 : 40, width: isSelected ? 48 : 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: isSelected ? [glowColor.withOpacity(0.8), glowColor] : [const Color(0xFF34495E), const Color(0xFF2C3E50)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.diamond, size: isSelected ? 14 : 12, color: isSelected ? Colors.white : glowColor),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: isSelected ? 10 : 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAmountButton() {
    bool isSelected = customBetAmount != null && selectedBetAmount == customBetAmount;
    String label = customBetAmount == null ? '✏️ Custom' : (customBetAmount! >= 1000 ? '${(customBetAmount! / 1000).toStringAsFixed(0)}K' : customBetAmount.toString());

    return GestureDetector(
      onTap: () {
        if (customBetAmount != null && !isSelected) {
          setState(() => selectedBetAmount = customBetAmount!);
        } else {
          setState(() {
            _keypadInput = customBetAmount?.toString() ?? "";
            _showKeypadOverlay = true;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), height: isSelected ? 48 : 40, width: isSelected ? 52 : 46, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : const Color(0xFF4A90E2), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customBetAmount != null) Icon(Icons.diamond, size: isSelected ? 12 : 10, color: Colors.white),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: customBetAmount == null ? 9 : (isSelected ? 10 : 8), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40, padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- INLINE DIALOGS ---

  Widget _buildInlineKeypad() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.35, 
          padding: const EdgeInsets.only(bottom: 12, top: 12, left: 12, right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B0B3B), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Colors.amberAccent.withOpacity(0.8), width: 2)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFF130624), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.diamond, color: Colors.amberAccent, size: 20),
                    Text(_keypadInput.isEmpty ? "0" : _keypadInput.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, childAspectRatio: 2.0, mainAxisSpacing: 6, crossAxisSpacing: 6,
                        children: [
                          _calcBtn('7', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '7'); }),
                          _calcBtn('8', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '8'); }),
                          _calcBtn('9', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '9'); }),
                          _calcBtn('4', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '4'); }),
                          _calcBtn('5', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '5'); }),
                          _calcBtn('6', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '6'); }),
                          _calcBtn('1', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '1'); }),
                          _calcBtn('2', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '2'); }),
                          _calcBtn('3', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '3'); }),
                          _calcBtn('0', () { if (_keypadInput.length < 9) setState(() => _keypadInput += '0'); }),
                          _calcBtn('00', () { if (_keypadInput.length < 8) setState(() => _keypadInput += '00'); }),
                          _calcBtn('000', () { if (_keypadInput.length < 7) setState(() => _keypadInput += '000'); }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(child: _calcIconBtn(Icons.backspace_outlined, const Color(0xFF4C2A85), () {
                            if (_keypadInput.isNotEmpty) setState(() => _keypadInput = _keypadInput.substring(0, _keypadInput.length - 1));
                          })), 
                          const SizedBox(height: 6),
                          Expanded(child: _calcIconBtn(Icons.keyboard_hide, const Color(0xFF4C2A85), () => setState(() => _showKeypadOverlay = false))), 
                          const SizedBox(height: 6),
                          Expanded(flex: 2, child: _calcIconBtn(Icons.check_circle, Colors.blueAccent, () {
                            if (_keypadInput.isNotEmpty) {
                              int parsed = int.tryParse(_keypadInput) ?? 0;
                              if (parsed > 0) {
                                setState(() {
                                  customBetAmount = parsed;
                                  selectedBetAmount = parsed;
                                });
                              }
                            }
                            setState(() => _showKeypadOverlay = false);
                          })),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineHistory() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: const BoxDecoration(
            color: Color(0xFF1B0B3B), borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: Colors.amberAccent, width: 2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24, width: 1))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("🕒 My Bet History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => setState(()=> _showHistoryOverlay = false), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                ),
              ),
              Expanded(
                child: personalBetHistory.isEmpty
                    ? const Center(child: Text("No bets placed yet.", style: TextStyle(color: Colors.white54, fontSize: 12)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: personalBetHistory.length,
                        itemBuilder: (context, index) {
                          final record = personalBetHistory[index];
                          final winningTarget = targets.firstWhere((t) => t.id == record.winningTargetId);
                          bool isWin = record.winnings > 0;
                          int profit = record.winnings - record.totalBet;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF281452), borderRadius: BorderRadius.circular(12), border: Border.all(color: isWin ? Colors.green.withOpacity(0.5) : Colors.white12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Round #${record.roundId}", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
                                    Text(isWin ? "+$profit 💎" : "$profit 💎", style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                                const Divider(color: Colors.white24, height: 12),
                                Row(
                                  children: [
                                    const Text("Winner: ", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text("${winningTarget.emoji} ${winningTarget.multiplier}x", style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text("Your Bets:", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6, runSpacing: 6,
                                  children: record.betsPlaced.entries.map((e) {
                                    final t = targets.firstWhere((tgt) => tgt.id == e.key);
                                    bool betWon = e.key == record.winningTargetId;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: betWon ? Colors.amber.withOpacity(0.2) : Colors.black26, border: Border.all(color: betWon ? Colors.amber : Colors.transparent), borderRadius: BorderRadius.circular(6)),
                                      child: Text("${t.emoji} ${e.value}", style: TextStyle(color: betWon ? Colors.amberAccent : Colors.white70, fontSize: 10)),
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
      ),
    );
  }

  // NEW: GLOBAL RESULTS HISTORY LEDGER
  Widget _buildInlineGlobalHistory() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: const BoxDecoration(
            color: Color(0xFF1B0B3B), borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: Colors.amberAccent, width: 2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24, width: 1))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("📄 Global Results History", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => setState(()=> _showGlobalHistoryOverlay = false), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                ),
              ),
              Expanded(
                child: globalHistory.isEmpty
                    ? const Center(child: Text("No results yet.", style: TextStyle(color: Colors.white54, fontSize: 12)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: globalHistory.length,
                        itemBuilder: (context, index) {
                          final record = globalHistory[index];
                          final target = targets.firstWhere((t) => t.id == record.targetId);
                          // Simple manual time format to avoid extra package dependencies
                          String formattedTime = "${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')}:${record.time.second.toString().padLeft(2, '0')}";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: const Color(0xFF281452), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Time: $formattedTime", style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text(target.emoji, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Text("${target.multiplier}x", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineLevelProgress() {
    double progress = currentXP / targetXP;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showLevelOverlay = false),
        child: Container(
          color: Colors.black.withOpacity(0.8),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A148C), Color(0xFF1B0B3B)]),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amberAccent, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 40, color: Colors.amber), const SizedBox(height: 8),
                Text("Level $currentLevel", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: Colors.black45, valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent)),
                ),
                const SizedBox(height: 10),
                Text("${currentXP.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} / ${targetXP.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} 💎", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineResult() {
    bool didWin = currentWinnings > 0;
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeResultOverlay,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withOpacity(0.8),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5B247A), Color(0xFF1B0B3B)]),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: didWin ? Colors.amber : const Color(0xFF8E44AD), width: 2),
              boxShadow: [BoxShadow(color: (didWin ? Colors.amber : Colors.deepPurple).withOpacity(0.6), blurRadius: 20, spreadRadius: 5)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(didWin ? "You got Diamond rewards!" : "Sorry, you didn't win a prize", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (didWin) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)])),
                      const Icon(Icons.shopping_bag, color: Colors.amber, size: 36),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('x${currentWinnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 3)])),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: const Text("Big winners", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
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

  Widget _calcBtn(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(decoration: BoxDecoration(color: const Color(0xFF2D165D), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
    );
  }

  Widget _calcIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Center(child: Icon(icon, color: Colors.white, size: 22))),
    );
  }

  Widget _buildWinnerAvatar(String name, int amount, int rank, Color crownColor, String imageUrl) {
    double size = rank == 1 ? 40 : 32;
    return Column(
      children: [
        Icon(Icons.military_tech, color: crownColor, size: rank == 1 ? 20 : 16),
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: crownColor, width: 2),
            boxShadow: [BoxShadow(color: crownColor.withOpacity(0.5), blurRadius: 4)],
            image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
          child: Row(
            children: [
              Icon(Icons.diamond, size: 6, color: Colors.blue.shade300), const SizedBox(width: 2),
              Text(amount >= 1000 ? '${(amount/1000).toStringAsFixed(0)}K' : amount.toString(), style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }
}

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
          double borderWidth = widget.isRollingFocus ? 2.5 : (showWinningEffect ? 2.5 : (hasBet ? 2.0 : 1.0));
          double scale = showWinningEffect ? 1.05 + (_winPulseController.value * 0.05) : (widget.isRollingFocus ? 1.05 : 1.0);

          return Transform.scale(
            scale: scale,
            child: Container(
              padding: EdgeInsets.all(borderWidth),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: widget.isRollingFocus || showWinningEffect ? [borderColor.withOpacity(0.9), Colors.white, borderColor.withOpacity(0.9)] : [borderColor, borderColor.withOpacity(0.3), borderColor],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: widget.isRollingFocus || showWinningEffect ? [BoxShadow(color: borderColor.withOpacity(0.8), blurRadius: 6, spreadRadius: 1)] : [],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 - borderWidth),
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
                  Text(widget.target.emoji, style: const TextStyle(fontSize: 22, shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))])), const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF1B0B3B), borderRadius: BorderRadius.circular(6)),
                    child: Text('1:${widget.target.multiplier}', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            if (widget.hotTag != null)
              Positioned(
                top: -1, left: -1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFF09819)]), borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(6)),
                  ),
                  child: Text(widget.hotTag!, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            if (hasBet)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 200), curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amberAccent, width: 1), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diamond, size: 8, color: Colors.amberAccent), const SizedBox(width: 2),
                            Text(widget.betAmount! >= 1000 ? '${(widget.betAmount!/1000).toStringAsFixed(0)}K' : widget.betAmount.toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
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