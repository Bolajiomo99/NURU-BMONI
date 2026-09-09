import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/onboarding_api.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_text_field.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Step 1: what the user's business looks like.
///
/// business_name is the one field the backend requires to save anything —
/// see BusinessProfileSerializer. Skip bypasses that entirely and discards
/// whatever was typed; Continue validates the name locally before saving.
class BusinessScreen extends ConsumerStatefulWidget {
  const BusinessScreen({super.key});

  @override
  ConsumerState<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends ConsumerState<BusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _payCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  OnboardingChoices _choices = const OnboardingChoices(
    businessSize: [],
    spendCategories: [],
    revenueRanges: [],
  );

  String _businessSize = '';
  bool? _hasEmployees;
  final Set<String> _spendCategories = {};
  String _revenueRange = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _payCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (business, choices) = await ref.read(onboardingApiProvider).getBusiness();
      if (!mounted) return;
      setState(() {
        _choices = choices;
        if (business != null) {
          _nameCtrl.text = business.businessName;
          _businessSize = business.businessSize;
          _hasEmployees = business.hasEmployees;
          _payCtrl.text =
              business.avgEmployeePay == null ? '' : business.avgEmployeePay.toString();
          _spendCategories.addAll(business.spendCategories);
          _revenueRange = business.avgMonthlyRevenueRange;
          _descriptionCtrl.text = business.description;
        }
      });
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToGoals() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingGoals);
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(onboardingApiProvider).patchBusiness({
        'business_name': _nameCtrl.text.trim(),
        if (_businessSize.isNotEmpty) 'business_size': _businessSize,
        if (_hasEmployees != null) 'has_employees': _hasEmployees,
        if (_hasEmployees == true && _payCtrl.text.trim().isNotEmpty)
          'avg_employee_pay': double.tryParse(_payCtrl.text.trim()),
        'spend_categories': _spendCategories.toList(),
        if (_revenueRange.isNotEmpty) 'avg_monthly_revenue_range': _revenueRange,
        if (_descriptionCtrl.text.trim().isNotEmpty)
          'description': _descriptionCtrl.text.trim(),
      });
      if (!mounted) return;
      _goToGoals();
    } on OnboardingException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: NuruTheme.primary)),
      );
    }

    return OnboardingScaffold(
      step: 1,
      title: 'Tell us about your business',
      subtitle: 'This helps NURU tailor insights to how you actually operate.',
      onContinue: _continue,
      onSkip: _goToGoals,
      continueLoading: _saving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NuruFormBanner(message: _error),
            NuruTextField(
              label: 'Business Name',
              controller: _nameCtrl,
              prefixIcon: Icons.storefront_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your business name' : null,
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Business Size'),
            _ChipGroup(
              options: _choices.businessSize,
              selected: {_businessSize},
              onTap: (value) => setState(
                () => _businessSize = _businessSize == value ? '' : value,
              ),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Do you have employees?'),
            Row(
              children: [
                _ToggleChip(
                  label: 'Yes',
                  selected: _hasEmployees == true,
                  onTap: () => setState(
                    () => _hasEmployees = _hasEmployees == true ? null : true,
                  ),
                ),
                const SizedBox(width: 10),
                _ToggleChip(
                  label: 'No',
                  selected: _hasEmployees == false,
                  onTap: () => setState(
                    () => _hasEmployees = _hasEmployees == false ? null : false,
                  ),
                ),
              ],
            ),
            if (_hasEmployees == true) ...[
              const SizedBox(height: 16),
              NuruTextField(
                label: 'Average Employee Pay (monthly)',
                controller: _payCtrl,
                prefixIcon: Icons.payments_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Where does the money go?'),
            _ChipGroup(
              options: _choices.spendCategories,
              selected: _spendCategories,
              onTap: (value) => setState(() {
                if (_spendCategories.contains(value)) {
                  _spendCategories.remove(value);
                } else {
                  _spendCategories.add(value);
                }
              }),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Average Monthly Revenue'),
            _ChipGroup(
              options: _choices.revenueRanges,
              selected: {_revenueRange},
              onTap: (value) => setState(
                () => _revenueRange = _revenueRange == value ? '' : value,
              ),
            ),
            const SizedBox(height: 20),
            NuruTextField(
              label: 'Anything else about your business? (optional)',
              controller: _descriptionCtrl,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: NuruTheme.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<ChoiceOption> options;
  final Set<String> selected;
  final void Function(String value) onTap;

  const _ChipGroup({required this.options, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => _ToggleChip(
                label: o.label,
                selected: selected.contains(o.value),
                onTap: () => onTap(o.value),
              ))
          .toList(),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? NuruTheme.primary.withValues(alpha: 0.15) : NuruTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? NuruTheme.primary : NuruTheme.surfaceElevated,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? NuruTheme.primary : NuruTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
