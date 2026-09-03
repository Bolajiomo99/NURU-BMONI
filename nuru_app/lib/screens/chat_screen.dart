import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/nuru_theme.dart';
import '../models/chat_message.dart';
import '../models/action_data.dart';
import '../providers/nuru_providers.dart';
import 'smart_action_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  final List<String> _suggestions = [
    'Can I afford to send \$100?',
    'Convert \$150 to NGN?',
    'How\'s my spending?',
    'Currency risk check',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    _textController.clear();
    HapticFeedback.lightImpact();
    setState(() => _isSending = true);

    await ref.read(chatProvider.notifier).sendMessage(text);

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      body: Column(
        children: [
          // ─── Custom Header ──────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              14,
            ),
            decoration: const BoxDecoration(
              color: NuruTheme.background,
              border: Border(
                bottom: BorderSide(color: NuruTheme.divider),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: NuruTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'N',
                      style: TextStyle(
                        color: Color(0xFF0A0E1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NURU AI',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: NuruTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: NuruTheme.healthyGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Connected to BMONI',
                            style: TextStyle(
                              fontSize: 12,
                              color: NuruTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(chatProvider.notifier).clearHistory();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: NuruTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: NuruTheme.textMuted,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Suggestion Chips ───────────────────
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _handleSend(_suggestions[index]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: NuruTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NuruTheme.divider),
                      ),
                      child: Text(
                        _suggestions[index],
                        style: const TextStyle(
                          fontSize: 13,
                          color: NuruTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Messages ──────────────────────────
          Expanded(
            child: chatState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: NuruTheme.primary),
              ),
              error: (err, st) => Center(
                child: Text(
                  'Error loading chat: $err',
                  style: const TextStyle(color: NuruTheme.textMuted),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _isSending) {
                      return const _BouncingDotsIndicator();
                    }

                    final message = messages[index];
                    return _ChatBubble(
                      message: message,
                      onActionTap: (action) {
                        ref.read(activeActionProvider.notifier).state = action;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SmartActionScreen(),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ─── Input Bar ─────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: NuruTheme.surface,
              border: Border(
                top: BorderSide(color: NuruTheme.divider),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: NuruTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(
                          color: NuruTheme.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask about your money...',
                          hintStyle: TextStyle(
                            color: NuruTheme.textMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _handleSend,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _handleSend(_textController.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isSending
                            ? null
                            : NuruTheme.primaryGradient,
                        color: _isSending ? NuruTheme.surfaceLight : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: NuruTheme.textMuted,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: Color(0xFF0A0E1A),
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: NuruTheme.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Color(0xFF0A0E1A),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How can I help today?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: NuruTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ask about affordability, spending patterns,\ncurrency conversion, or financial advice.',
              style: TextStyle(
                fontSize: 14,
                color: NuruTheme.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Bubble ───────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessageItem message;
  final Function(NuruAction) onActionTap;

  const _ChatBubble({
    required this.message,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: NuruTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Color(0xFF0A0E1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? NuruTheme.primary : NuruTheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: NuruTheme.divider),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser
                          ? const Color(0xFF0A0E1A)
                          : NuruTheme.textPrimary,
                    ),
                  ),
                ),

                // Embedded action card
                if (message.hasAction && message.action != null) ...[
                  const SizedBox(height: 10),
                  _ActionCard(
                    action: message.action!,
                    onPressed: () => onActionTap(message.action!),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Action Card ───────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final NuruAction action;
  final VoidCallback onPressed;

  const _ActionCard({required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isTransfer = action.type == 'transfer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NuruTheme.accentSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NuruTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: NuruTheme.accentLight,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Recommended Action',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: NuruTheme.accentLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTransfer
                ? 'Send \$${action.amount.toStringAsFixed(2)} ${action.currency}'
                : 'Convert \$${action.amount.toStringAsFixed(2)} → ${action.toCurrency}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: NuruTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: NuruTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isTransfer
                    ? 'Send \$${action.amount.toStringAsFixed(0)} →'
                    : 'Convert →',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bouncing Dots Typing Indicator ────────────────────────────────
class _BouncingDotsIndicator extends StatefulWidget {
  const _BouncingDotsIndicator();

  @override
  State<_BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<_BouncingDotsIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) controller.repeat(reverse: true);
      });
      return controller;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: NuruTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Color(0xFF0A0E1A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: NuruTheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: NuruTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.translate(
                        offset: Offset(0, -4 * _controllers[i].value),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: NuruTheme.primary.withValues(
                              alpha: 0.4 + 0.6 * _controllers[i].value,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
