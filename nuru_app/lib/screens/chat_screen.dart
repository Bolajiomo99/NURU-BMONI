import 'package:flutter/material.dart';
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
    'Can I afford to send \$100 to my family?',
    'Should I convert \$150 USD to NGN?',
    'How\'s my spending this month?',
    'What\'s my currency concentration risk?',
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
      appBar: AppBar(
        title: Column(
          children: const [
            Text(
              'Ask NURU',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 2),
            Text(
              '🟢 Connected to BMONI Data',
              style: TextStyle(fontSize: 11, color: NuruTheme.healthyGreen),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: NuruTheme.textMuted),
            onPressed: () {
              ref.read(chatProvider.notifier).clearHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Suggestions horizontal scrollable chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 12, color: NuruTheme.textPrimary),
                    ),
                    backgroundColor: NuruTheme.surfaceLight.withOpacity(0.4),
                    side: BorderSide(color: NuruTheme.surfaceLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _handleSend(suggestion),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: NuruTheme.surfaceLight),

          // Messages List
          Expanded(
            child: chatState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: NuruTheme.primary),
              ),
              error: (err, st) => Center(
                child: Text('Error loading chat: $err'),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.psychology, size: 64, color: NuruTheme.primaryLight),
                          SizedBox(height: 16),
                          Text(
                            'How can NURU help you today?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: NuruTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ask questions about affordability, currency conversion, or spending insights.',
                            style: TextStyle(fontSize: 13, color: NuruTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _isSending) {
                      return const _TypingIndicatorBubble();
                    }

                    final message = messages[index];
                    return _ChatMessageBubble(
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

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NuruTheme.surface,
              border: Border(
                top: BorderSide(color: NuruTheme.surfaceLight),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: NuruTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ask NURU anything about your money...',
                        hintStyle: const TextStyle(color: NuruTheme.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: NuruTheme.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _handleSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: NuruTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _handleSend(_textController.text),
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

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessageItem message;
  final Function(NuruAction) onActionTap;

  const _ChatMessageBubble({
    required this.message,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: NuruTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? NuruTheme.primary
                        : NuruTheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: NuruTheme.surfaceLight),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser ? Colors.white : NuruTheme.textPrimary,
                    ),
                  ),
                ),

                // Embedded Action Card if AI recommended an action
                if (message.hasAction && message.action != null) ...[
                  const SizedBox(height: 10),
                  _ActionCardWidget(
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

class _ActionCardWidget extends StatelessWidget {
  final NuruAction action;
  final VoidCallback onPressed;

  const _ActionCardWidget({
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isTransfer = action.type == 'transfer';
    final buttonText = isTransfer
        ? 'Send \$${action.amount.toStringAsFixed(0)} →'
        : 'Convert \$${action.amount.toStringAsFixed(0)} → ${action.toCurrency}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NuruTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NuruTheme.accentLight.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: NuruTheme.accentLight, size: 18),
              const SizedBox(width: 6),
              Text(
                'RECOMMENDED ACTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: NuruTheme.accentLight,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isTransfer
                ? 'Transfer \$${action.amount.toStringAsFixed(2)} ${action.currency} to ${action.to}'
                : 'Convert \$${action.amount.toStringAsFixed(2)} USD to ${action.toCurrency}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
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
                backgroundColor: NuruTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: NuruTheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: NuruTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NuruTheme.surfaceLight),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NuruTheme.primaryLight,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'NURU is analyzing...',
                  style: TextStyle(fontSize: 13, color: NuruTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
