import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import '../../utils/colors.dart';

class AiCoachCard extends StatefulWidget {
  final String userId;
  final String username;
  final int remainingDays;

  const AiCoachCard({
    super.key,
    required this.userId,
    required this.username,
    required this.remainingDays,
  });

  @override
  State<AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends State<AiCoachCard> {
  final AiService _aiService = AiService();
  List<String> _heuristicTips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoachTips();
  }

  Future<void> _loadCoachTips() async {
    setState(() => _isLoading = true);
    try {
      final tips = await _aiService.generateHeuristicTips(widget.userId);
      setState(() {
        _heuristicTips = tips;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showChatDialog() {
    final textController = TextEditingController();
    final List<Map<String, String>> chatHistory = [
      {
        "sender": "coach",
        "text": "Hello ${widget.username}! I am your offline AI Life Coach. How can I help you stay on track with your goals today? (Ask about: protein, sleep, relapse, saving, or study strategies)"
      }
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.chat_bubble_rounded, color: AppColors.accent),
                  SizedBox(width: 12),
                  Text("Chat with AI Coach", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: chatHistory.length,
                        itemBuilder: (context, index) {
                          final msg = chatHistory[index];
                          final isCoach = msg["sender"] == "coach";
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            alignment: isCoach ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isCoach ? AppColors.border : AppColors.accent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg["text"]!,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: "Type your query...",
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) {
                              final text = textController.text.trim();
                              if (text.isEmpty) return;
                              setDialogState(() {
                                chatHistory.add({"sender": "user", "text": text});
                                textController.clear();
                              });

                              // Get offline heuristics response
                              final reply = _aiService.getChatResponse(text, widget.userId);
                              Future.delayed(const Duration(milliseconds: 300), () {
                                setDialogState(() {
                                  chatHistory.add({"sender": "coach", "text": reply});
                                });
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.accent),
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            setDialogState(() {
                              chatHistory.add({"sender": "user", "text": text});
                              textController.clear();
                            });

                            // Get offline heuristics response
                            final reply = _aiService.getChatResponse(text, widget.userId);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              setDialogState(() {
                                chatHistory.add({"sender": "coach", "text": reply});
                              });
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationSimulationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final times = ['6:00 AM', '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM'];
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Simulated Daily Reminders",
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tap any scheduled slot to fire a simulated local notification alert:",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: times.length,
                  itemBuilder: (context, idx) {
                    final time = times[idx];
                    return ListTile(
                      leading: const Icon(Icons.alarm_rounded, color: AppColors.accent),
                      title: Text(time, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.success),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Simulated push for \$time triggered!"),
                            backgroundColor: AppColors.accent,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                "🤖 AI LIFE COACH",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            "Good Morning, ${widget.username}! ☀️",
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            "I analyzed your database indicators. Here is my local offline insight for you:",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.accent))
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _heuristicTips.map((tip) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _showChatDialog,
                icon: const Icon(Icons.chat_outlined, size: 16, color: AppColors.accent),
                label: const Text("Ask Coach", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _loadCoachTips,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
                label: const Text("Refresh Tips", style: TextStyle(color: AppColors.textSecondary)),
              ),
              IconButton(
                icon: const Icon(Icons.alarm_rounded, color: AppColors.success),
                tooltip: "Trigger Simulated Reminders",
                onPressed: _showNotificationSimulationsSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
