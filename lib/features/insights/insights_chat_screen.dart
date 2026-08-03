import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/gemini_service.dart';

class InsightsChatScreen extends StatefulWidget {
  const InsightsChatScreen({super.key});

  @override
  State<InsightsChatScreen> createState() => _InsightsChatScreenState();
}

class _InsightsChatScreenState extends State<InsightsChatScreen> {
  final _db = DatabaseHelper.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<TransactionModel> _transactions = [];
  double _monthlyIncome = 0.0;
  bool _loadingData = true;

  final List<Map<String, String>> _messages = [
    {
      'role': 'model',
      'text': "Hi! I'm your FinPulse AI Coach. Ask me anything about your spending habits, budget, or how to save better."
    }
  ];
  bool _thinking = false;

  final List<String> _suggestions = [
    "How's my saving mindset?",
    "Tell me about late night flags.",
    "Show my 30-day summary.",
    "Tip to reduce discretionary spend.",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final txs = await _db.getAllTransactions();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final income = await _db.getTotalIncome(start: monthStart, end: monthEnd);

    setState(() {
      _transactions = txs;
      _monthlyIncome = income > 0 ? income : 50000.0;
      _loadingData = false;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _thinking) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _thinking = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Call GeminiService chat
    final response = await GeminiService.chat(
      history: _messages,
      transactions: _transactions,
      monthlyIncome: _monthlyIncome,
    );

    if (mounted) {
      setState(() {
        _messages.add({'role': 'model', 'text': response});
        _thinking = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_rounded, color: Color(0xFF3B82F6), size: 24),
            SizedBox(width: 8),
            Text(
              "AI Financial Coach",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length + (_thinking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _thinking) {
                          return _buildThinkingBubble();
                        }
                        return _buildChatBubble(_messages[index]);
                      },
                    ),
                  ),

                  // Suggestions list
                  if (_messages.length == 1 && !_thinking) _buildSuggestions(),

                  // Text input container
                  _buildInputArea(),
                ],
              ),
            ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final s = _suggestions[index];
          return GestureDetector(
            onTap: () => _sendMessage(s),
            child: Container(
              margin: const EdgeInsets.only(right: 8, bottom: 6, top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              alignment: Alignment.center,
              child: Text(
                s,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg['text'] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: Color(0xFF3B82F6),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
