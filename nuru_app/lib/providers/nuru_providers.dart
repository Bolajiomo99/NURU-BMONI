import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_data.dart';
import '../models/chat_message.dart';
import '../models/action_data.dart';
import '../services/api_service.dart';

// Dashboard Data Provider
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  return await ApiService.fetchDashboard();
});

// Active Action Provider (selected for execution)
final activeActionProvider = StateProvider<NuruAction?>((ref) => null);

// Chat Messages State Notifier
class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessageItem>>> {
  ChatNotifier() : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final messages = await ApiService.fetchChatHistory();
      state = AsyncValue.data(messages);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> sendMessage(String text) async {
    final currentList = state.value ?? [];
    final userMsg = ChatMessageItem(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    // Optimistic user message addition
    state = AsyncValue.data([...currentList, userMsg]);

    try {
      final aiResponse = await ApiService.sendMessage(text);
      state = AsyncValue.data([...state.value ?? [], aiResponse]);
    } catch (e) {
      final errorMsg = ChatMessageItem(
        role: 'assistant',
        content: "Sorry, I couldn't reach NURU servers. Please check connection.",
        timestamp: DateTime.now(),
      );
      state = AsyncValue.data([...state.value ?? [], errorMsg]);
    }
  }

  Future<void> clearHistory() async {
    await ApiService.clearChatHistory();
    state = const AsyncValue.data([]);
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessageItem>>>((ref) {
  return ChatNotifier();
});

// Explain My Money Provider
final explainStoryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return await ApiService.explainFinances();
});
