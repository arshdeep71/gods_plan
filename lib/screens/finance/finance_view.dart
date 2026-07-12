import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../utils/colors.dart';

class FinanceView extends StatefulWidget {
  const FinanceView({super.key});

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<FinanceProvider>(context, listen: false).fetchTransactions(user.id);
      }
    });
  }

  void _showAddTransactionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return const AddTransactionSheet();
      },
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return const FinanceSettingsSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final txs = financeProvider.transactions;
    final dailyTarget = financeProvider.dailySavingsTarget;
    final monthlyTarget = financeProvider.monthlySavingsTarget;
    final bigGoalTarget = financeProvider.bigSavingsTarget;

    final todayNet = financeProvider.todayNetSavings;
    final monthlyNet = financeProvider.monthlyNetSavings;
    final totalSaved = financeProvider.totalSaved;

    final dailyProgress = (todayNet / dailyTarget).clamp(0.0, 1.0);
    final monthlyProgress = (monthlyNet / monthlyTarget).clamp(0.0, 1.0);
    final bigProgress = (totalSaved / bigGoalTarget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Money & Savings", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () => _showSettingsModal(context),
          ),
        ],
      ),
      body: financeProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily target progress card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Daily Savings",
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Net saved today",
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: todayNet >= dailyTarget
                                    ? Colors.green.withOpacity(0.1)
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                todayNet >= dailyTarget ? "Goal Met ✓" : "Saving Mode",
                                style: TextStyle(
                                  color: todayNet >= dailyTarget ? Colors.green : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "₹${todayNet.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Target: ₹${dailyTarget.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    value: dailyProgress,
                                    backgroundColor: AppColors.border,
                                    color: Colors.green,
                                    strokeWidth: 6,
                                  ),
                                ),
                                Text(
                                  "${(dailyProgress * 100).toStringAsFixed(0)}%",
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Monthly and Big targets
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("This Month", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(
                                "₹${monthlyNet.toStringAsFixed(0)}",
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: monthlyProgress,
                                backgroundColor: AppColors.border,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Goal: ₹${monthlyTarget.toStringAsFixed(0)}",
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Big Goal", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(
                                "₹${totalSaved.toStringAsFixed(0)}",
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: bigProgress,
                                backgroundColor: AppColors.border,
                                color: Colors.purple,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Goal: ₹${bigGoalTarget.toStringAsFixed(0)}",
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Ledger / Transactions list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Transaction Ledger",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddTransactionModal(context),
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                        label: const Text(
                          "Add Ledger Entry",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (txs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            "No transactions logged today.",
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Track your tutoring, freelance income, and food or commute expenses.",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            textAlign: Center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: txs.length,
                      itemBuilder: (context, index) {
                        final tx = txs[index];
                        final isIncome = tx.type == 'income';
                        final user = Provider.of<AuthProvider>(context, listen: false).user;
                        return Dismissible(
                          key: Key(tx.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            if (user != null) {
                              financeProvider.deleteTransaction(user.id, tx.id);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isIncome
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  child: Icon(
                                    isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                                    color: isIncome ? Colors.green : Colors.red,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            tx.category,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            "${isIncome ? '+' : '-'}₹${tx.amount.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              color: isIncome ? Colors.green : Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            tx.notes.isNotEmpty ? tx.notes : "No notes",
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(tx.loggedAt),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minuteString = local.minute.toString().padLeft(2, '0');
    final monthString = _monthAbbr(local.month);
    return "$monthString ${local.day}, $hour:$minuteString $period";
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  String _type = 'expense'; // 'income' or 'expense'
  String _category = 'Food';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _incomeCategories = ["Freelance", "Tutoring", "Pocket Money", "Salary", "Other"];
  final List<String> _expenseCategories = ["Food", "Transport", "Phone Bill", "Entertainment", "Study", "Misc"];

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    final categories = _type == 'income' ? _incomeCategories : _expenseCategories;
    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Add Ledger Entry",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Segment selector
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = 'income';
                        _category = _incomeCategories.first;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'income' ? Colors.green.withOpacity(0.15) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == 'income' ? Colors.green : AppColors.border,
                        ),
                      ),
                      child: Text(
                        "Income (+)",
                        style: TextStyle(
                          color: _type == 'income' ? Colors.green : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = 'expense';
                        _category = _expenseCategories.first;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'expense' ? Colors.red.withOpacity(0.15) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == 'expense' ? Colors.red : AppColors.border,
                        ),
                      ),
                      child: Text(
                        "Expense (-)",
                        style: TextStyle(
                          color: _type == 'expense' ? Colors.red : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount
            const Text(
              "Amount (₹)",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: "Enter transaction amount",
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            const Text(
              "Category",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppColors.surface,
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _category = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Notes
            const Text(
              "Notes / Context",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: "e.g., UI client payment, Lunch out, Bus fare",
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'income' ? Colors.green : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final amount = double.tryParse(_amountController.text) ?? 0.0;
                  if (amount > 0 && user != null) {
                    financeProvider.addTransaction(
                      userId: user.id,
                      type: _type,
                      category: _category,
                      amount: amount,
                      notes: _notesController.text,
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text(
                  "Save Transaction",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceSettingsSheet extends StatefulWidget {
  const FinanceSettingsSheet({super.key});

  @override
  State<FinanceSettingsSheet> createState() => _FinanceSettingsSheetState();
}

class _FinanceSettingsSheetState extends State<FinanceSettingsSheet> {
  final TextEditingController _dailyController = TextEditingController();
  final TextEditingController _monthlyController = TextEditingController();
  final TextEditingController _bigController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = Provider.of<FinanceProvider>(context, listen: false);
    _dailyController.text = p.dailySavingsTarget.toStringAsFixed(0);
    _monthlyController.text = p.monthlySavingsTarget.toStringAsFixed(0);
    _bigController.text = p.bigSavingsTarget.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<FinanceProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Configure Savings Targets",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Daily Target
            const Text("Daily Savings Target (₹)", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _dailyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Monthly Target
            const Text("Monthly Savings Target (₹)", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _monthlyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Big Target
            const Text("Total Big Savings Target (₹)", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _bigController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final daily = double.tryParse(_dailyController.text) ?? 500.0;
                  final monthly = double.tryParse(_monthlyController.text) ?? 15000.0;
                  final big = double.tryParse(_bigController.text) ?? 50000.0;
                  p.updateTargets(daily: daily, monthly: monthly, big: big);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Save Targets",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
