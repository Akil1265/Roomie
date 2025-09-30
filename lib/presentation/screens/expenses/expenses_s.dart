import 'package:flutter/material.dart';
import 'package:roomie/data/models/expense_model.dart';
import 'package:roomie/data/datasources/expense_service.dart';
import 'package:roomie/presentation/widgets/expense_card.dart';

class ExpensesScreen extends StatefulWidget {
  final String groupId;

  const ExpensesScreen({super.key, required this.groupId});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _expenseService = ExpenseService();
  List<ExpenseModel> _expenses = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final expenses = await _expenseService.getGroupExpenses(widget.groupId).first;
      final summary = await _expenseService.getExpensesSummary(widget.groupId);
      
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_summary.isNotEmpty) ExpenseSummaryCard(summary: _summary),
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(
                          child: Text('No expenses yet'),
                        )
                      : ListView.builder(
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            return ExpenseCard(expense: _expenses[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}