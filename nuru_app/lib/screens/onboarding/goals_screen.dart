import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/onboarding_api.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Step 2: goals the user wants NURU to help them reach. Entirely optional —
/// unlike the business step there is no required field, so Continue and Skip
/// both just move on; whatever was already added stays added either way.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _inputCtrl = TextEditingController();
  List<BusinessGoal> _goals = [];
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final goals = await ref.read(onboardingApiProvider).getGoals();
      if (mounted) setState(() => _goals = goals);
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addGoal() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _adding) return;

    setState(() {
      _adding = true;
      _error = null;
    });

    try {
      final goal = await ref.read(onboardingApiProvider).createGoal(text);
      if (!mounted) return;
      setState(() {
        _goals = [..._goals, goal];
        _inputCtrl.clear();
      });
    } on OnboardingException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not add that goal. Try again.');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteGoal(BusinessGoal goal) async {
    final previous = _goals;
    setState(() => _goals = _goals.where((g) => g.id != goal.id).toList());
    try {
      await ref.read(onboardingApiProvider).deleteGoal(goal.id);
    } catch (_) {
      // Restore on failure rather than silently losing the goal from view.
      if (mounted) setState(() => _goals = previous);
    }
  }

  void _continue() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingConnect);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: NuruTheme.primary)),
      );
    }

    return OnboardingScaffold(
      step: 2,
      title: 'What are you working toward?',
      subtitle: 'Add a few goals — NURU will nudge you toward them as it learns your finances.',
      onContinue: _continue,
      onSkip: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NuruFormBanner(message: _error),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 15),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addGoal(),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Save ₦500,000 for new equipment',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _adding ? null : NuruTheme.primaryGradient,
                    color: _adding ? NuruTheme.surfaceLight : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: _adding ? null : _addGoal,
                    icon: _adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(NuruTheme.textMuted),
                            ),
                          )
                        : const Icon(Icons.add_rounded, color: Color(0xFF0A0E1A)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final goal in _goals) _GoalTile(goal: goal, onDelete: () => _deleteGoal(goal)),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final BusinessGoal goal;
  final VoidCallback onDelete;

  const _GoalTile({required this.goal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NuruTheme.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: NuruTheme.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goal.goalText,
              style: const TextStyle(fontSize: 14, color: NuruTheme.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded, color: NuruTheme.textMuted, size: 18),
          ),
        ],
      ),
    );
  }
}
