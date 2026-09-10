import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/onboarding_api.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_primary_button.dart';
import '../../widgets/nuru_text_field.dart';
import '../../widgets/onboarding_scaffold.dart';
import 'mono_webview_screen.dart';

/// Step 3: link a bank account via Mono, and/or record an existing loan.
/// Either one satisfies this step server-side (OnboardingStatusView's
/// `section_three = has_accounts or has_loans`), but neither is required to
/// finish onboarding locally — Continue and Skip both land on /home.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  bool _loading = true;
  bool _linking = false;
  bool _waitingOnNewTab = false;
  String? _error;
  String? _info;
  List<ConnectedAccount> _accounts = [];
  List<Loan> _loans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(onboardingApiProvider);
    try {
      final results = await Future.wait([api.monoAccounts(), api.getLoans()]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<ConnectedAccount>;
        _loans = results[1] as List<Loan>;
      });
    } catch (_) {
      // Best-effort: an empty state is fine, the screen still works.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _linking = true;
      _error = null;
      _info = null;
    });

    final api = ref.read(onboardingApiProvider);
    try {
      final initiate = await api.monoInitiate();
      final monoUrl = initiate['mono_url'] ?? '';
      if (monoUrl.isEmpty) {
        throw const OnboardingException(message: 'Mono did not return a widget link.');
      }

      if (kIsWeb) {
        await launchUrl(Uri.parse(monoUrl), mode: LaunchMode.externalApplication);
        if (mounted) {
          setState(() {
            _waitingOnNewTab = true;
            _info = 'Finish linking your account in the new tab, then come back and tap '
                '"I\'ve finished linking" below.';
          });
        }
        return;
      }

      if (!mounted) return;
      final code = await Navigator.of(context).push<String?>(
        MaterialPageRoute(
          builder: (_) => MonoWebViewScreen(
            monoUrl: monoUrl,
            redirectUrl: initiate['redirect_url'] ?? '',
          ),
        ),
      );
      if (code == null || code.isEmpty) return; // user backed out

      final account = await api.monoCallback(code: code, ref: initiate['ref'] ?? '');
      if (!mounted) return;
      setState(() => _accounts = [account, ..._accounts]);
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start account linking. Try again.');
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _refreshAfterNewTab() async {
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      final accounts = await ref.read(onboardingApiProvider).monoAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _waitingOnNewTab = accounts.isEmpty;
        _info = accounts.isEmpty
            ? 'Still no linked account yet — finish in the other tab, then try again.'
            : null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not check yet. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _addLoan(_LoanDraft draft) async {
    try {
      final loan = await ref.read(onboardingApiProvider).createLoan(
            amount: draft.amount!,
            interestRate: draft.interestRate,
            dateTaken: draft.dateTaken!.toIso8601String().split('T').first,
            dueDate: draft.dueDate?.toIso8601String().split('T').first,
            lenderName: draft.lenderName,
          );
      if (mounted) setState(() => _loans = [loan, ..._loans]);
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save that loan. Try again.');
    }
  }

  Future<void> _deleteLoan(Loan loan) async {
    final previous = _loans;
    setState(() => _loans = _loans.where((l) => l.id != loan.id).toList());
    try {
      await ref.read(onboardingApiProvider).deleteLoan(loan.id);
    } catch (_) {
      if (mounted) setState(() => _loans = previous);
    }
  }

  void _finish() {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
  }

  void _openAddLoanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NuruTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddLoanSheet(onSave: _addLoan),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: NuruTheme.primary)),
      );
    }

    final connected = _accounts.where((a) => a.status == 'connected').toList();

    return OnboardingScaffold(
      step: 3,
      title: 'Connect your finances',
      subtitle: 'Link a bank account and note any existing loans — both are optional.',
      onContinue: _finish,
      onSkip: _finish,
      continueLabel: 'Finish Setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NuruFormBanner(message: _error),
          NuruFormBanner(message: _info, kind: NuruBannerKind.info),
          const _SectionLabel('Bank Account'),
          for (final account in connected) _AccountTile(account: account),
          if (connected.isEmpty) ...[
            NuruPrimaryButton(
              label: _waitingOnNewTab ? "I've finished linking" : 'Connect Bank Account',
              icon: Icons.account_balance_outlined,
              isLoading: _linking,
              onPressed: _linking ? null : (_waitingOnNewTab ? _refreshAfterNewTab : _connect),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: _SectionLabel('Existing Loans')),
              TextButton.icon(
                onPressed: _openAddLoanSheet,
                icon: const Icon(Icons.add_rounded, size: 18, color: NuruTheme.primary),
                label: const Text('Add', style: TextStyle(color: NuruTheme.primary)),
              ),
            ],
          ),
          for (final loan in _loans) _LoanTile(loan: loan, onDelete: () => _deleteLoan(loan)),
          if (_loans.isEmpty)
            const Text(
              'No loans added yet.',
              style: TextStyle(fontSize: 13, color: NuruTheme.textMuted),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: NuruTheme.textPrimary,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final ConnectedAccount account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NuruTheme.healthyGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NuruTheme.healthyGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: NuruTheme.healthyGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.institutionName.isNotEmpty ? account.institutionName : 'Bank account',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                if (account.accountNumberMasked.isNotEmpty)
                  Text(
                    '•••• ${account.accountNumberMasked}',
                    style: const TextStyle(fontSize: 12, color: NuruTheme.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final Loan loan;
  final VoidCallback onDelete;
  const _LoanTile({required this.loan, required this.onDelete});

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
          const Icon(Icons.request_quote_outlined, color: NuruTheme.accent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.lenderName.isNotEmpty ? loan.lenderName : 'Loan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                Text(
                  '₦${loan.amount.toStringAsFixed(0)} · taken ${loan.dateTaken}',
                  style: const TextStyle(fontSize: 12, color: NuruTheme.textMuted),
                ),
              ],
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

class _LoanDraft {
  double? amount;
  double? interestRate;
  DateTime? dateTaken;
  DateTime? dueDate;
  String lenderName = '';
}

class _AddLoanSheet extends StatefulWidget {
  final void Function(_LoanDraft draft) onSave;
  const _AddLoanSheet({required this.onSave});

  @override
  State<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<_AddLoanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  DateTime? _dateTaken;
  DateTime? _dueDate;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _lenderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isDueDate ? _dueDate = picked : _dateTaken = picked);
  }

  String _fmt(DateTime? d) => d == null ? 'Select date' : d.toIso8601String().split('T').first;

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateTaken == null) return;

    widget.onSave(_LoanDraft()
      ..amount = double.tryParse(_amountCtrl.text.trim())
      ..interestRate = double.tryParse(_rateCtrl.text.trim())
      ..dateTaken = _dateTaken
      ..dueDate = _dueDate
      ..lenderName = _lenderCtrl.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a Loan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: NuruTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              NuruTextField(
                label: 'Amount',
                controller: _amountCtrl,
                prefixIcon: Icons.payments_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v?.trim() ?? '') == null)
                    ? 'Enter a valid amount'
                    : null,
              ),
              const SizedBox(height: 16),
              NuruTextField(
                label: 'Interest Rate % (optional)',
                controller: _rateCtrl,
                prefixIcon: Icons.percent_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              NuruTextField(
                label: 'Lender (optional)',
                controller: _lenderCtrl,
                prefixIcon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Date Taken',
                      value: _fmt(_dateTaken),
                      onTap: () => _pickDate(isDueDate: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Due Date (optional)',
                      value: _fmt(_dueDate),
                      onTap: () => _pickDate(isDueDate: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              NuruPrimaryButton(label: 'Save Loan', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: NuruTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: NuruTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: NuruTheme.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
