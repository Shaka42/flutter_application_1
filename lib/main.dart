import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Budget Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Material 3 design with a clean color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const BudgetCalculatorPage(),
    );
  }
}

// Model class to represent an expense
class Expense {
  final String name;
  final double amount;

  Expense({required this.name, required this.amount});

  // Convert Expense to Map for easy storage
  Map<String, dynamic> toMap() {
    return {'name': name, 'amount': amount};
  }

  // Create Expense from Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      name: map['name'] as String,
      amount: map['amount'] as double,
    );
  }
}

class BudgetCalculatorPage extends StatefulWidget {
  const BudgetCalculatorPage({super.key});

  @override
  State<BudgetCalculatorPage> createState() => _BudgetCalculatorPageState();
}

class _BudgetCalculatorPageState extends State<BudgetCalculatorPage> {
  // Controllers for text input fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // List to store all expenses in memory
  final List<Expense> _expenses = [];

  // Variable to track total spending
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    // Load saved total from shared_preferences when app starts
    _loadSavedTotal();
  }

  @override
  void dispose() {
    // Clean up controllers when widget is disposed
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Load the saved total amount from shared_preferences
  Future<void> _loadSavedTotal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalAmount = prefs.getDouble('totalAmount') ?? 0.0;
    });
  }

  // Save the total amount to shared_preferences
  Future<void> _saveTotalAmount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalAmount', _totalAmount);
  }

  // Calculate total from all expenses
  void _calculateTotal() {
    double total = 0.0;
    for (var expense in _expenses) {
      total += expense.amount;
    }
    setState(() {
      _totalAmount = total;
    });
    // Save the total to persistent storage
    _saveTotalAmount();
  }

  // Add new expense to the list
  void _addExpense() {
    // Get input values
    final String name = _nameController.text.trim();
    final String amountText = _amountController.text.trim();

    // Validate inputs
    if (name.isEmpty) {
      _showSnackBar('Please enter an expense name');
      return;
    }

    if (amountText.isEmpty) {
      _showSnackBar('Please enter an amount');
      return;
    }

    // Parse amount and validate
    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid positive amount');
      return;
    }

    // Create new expense and add to list
    final newExpense = Expense(name: name, amount: amount);
    setState(() {
      _expenses.add(newExpense);
    });

    // Recalculate total
    _calculateTotal();

    // Clear input fields
    _nameController.clear();
    _amountController.clear();

    // Show confirmation
    _showSnackBar('Expense added successfully!');

    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  // Reset all expenses and total
  void _resetExpenses() {
    setState(() {
      _expenses.clear();
      _totalAmount = 0.0;
    });

    // Clear saved total from shared_preferences
    _saveTotalAmount();

    _showSnackBar('All expenses cleared!');
  }

  // Show a snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Personal Budget Calculator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Input Section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Expense Name Input Field
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Expense Name',
                      hintText: 'e.g., Groceries, Rent, etc.',
                      prefixIcon: const Icon(Icons.label_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),

                  // Amount Input Field (numeric only)
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      // Allow only numbers and decimal point
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Buttons Row
                  Row(
                    children: [
                      // Add Expense Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _addExpense,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Expense'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reset Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _expenses.isEmpty ? null : _resetExpenses,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Expenses List Section
            Expanded(
              child: _expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No expenses yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first expense above',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.receipt,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              expense.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Text(
                              '\$${expense.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Total Amount Display Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount Spent:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${_totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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
}
