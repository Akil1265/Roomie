import 'package:flutter/material.dart';
import 'package:roomie/data/models/expense_model.dart';

class BalanceTile extends StatelessWidget {
  final UserBalance balance;
  final VoidCallback? onTap;

  const BalanceTile({
    super.key,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance.netBalance >= 0;
    final absAmount = balance.netBalance.abs();
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getUserColor(balance.userName),
                ),
                child: Center(
                  child: Text(
                    _getInitials(balance.userName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF121417),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owes: ₹${balance.totalOwed.toStringAsFixed(2)} • Paid: ₹${balance.totalPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Balance amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPositive 
                          ? const Color(0xFFE8F5E8)
                          : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive 
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: isPositive 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₹${absAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isPositive 
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF9800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPositive ? 'You\'ll get' : 'You owe',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return 'U';
  }

  Color _getUserColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFFEC4899),
      const Color(0xFF84CC16),
    ];
    
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }
}

// Overall balance summary widget
class BalanceSummaryCard extends StatelessWidget {
  final double totalOwed;
  final double totalToReceive;
  final int activeExpenses;
  final VoidCallback? onViewAll;

  const BalanceSummaryCard({
    super.key,
    required this.totalOwed,
    required this.totalToReceive,
    required this.activeExpenses,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final netBalance = totalToReceive - totalOwed;
    final isPositive = netBalance >= 0;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF121417),
              const Color(0xFF2D3748),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Net balance
            Row(
              children: [
                Icon(
                  isPositive 
                      ? Icons.account_balance_wallet
                      : Icons.credit_card,
                  color: isPositive 
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF5722),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${netBalance.abs().toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              isPositive ? 'You\'ll receive' : 'You owe',
              style: TextStyle(
                color: isPositive 
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF5722),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Breakdown
            Row(
              children: [
                Expanded(
                  child: _buildBreakdownItem(
                    'To Receive',
                    totalToReceive,
                    const Color(0xFF4CAF50),
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBreakdownItem(
                    'To Pay',
                    totalOwed,
                    const Color(0xFFFF5722),
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Active expenses
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeExpenses Active Expenses',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
