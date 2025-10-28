import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? true;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await prefs.setBool('isDarkMode', newMode == ThemeMode.dark);
    setState(() {
      _themeMode = newMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF2ECC71),
          secondary: const Color(0xFF3498DB),
          surface: Colors.white,
          background: Colors.white,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: Colors.grey[100],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2ECC71),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF2C2C2E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2ECC71),
          secondary: const Color(0xFF3498DB),
          surface: const Color(0xFF3A3A3C),
          background: const Color(0xFF2C2C2E),
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF3A3A3C),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C2C2E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: _themeMode,
      home: HomePage(onThemeToggle: _toggleTheme, themeMode: _themeMode),
    );
  }
}

// Models
class Account {
  final String name;
  final double balance;
  final Color color;
  final IconData icon;

  Account({
    required this.name,
    required this.balance,
    required this.color,
    required this.icon,
  });

  // Convert Account to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'balance': balance,
      'colorValue': color.value,
      'iconCode': icon.codePoint,
    };
  }

  // Create Account from Map
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      name: map['name'] as String,
      balance: map['balance'] as double,
      color: Color(map['colorValue'] as int),
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
    );
  }
}

class Category {
  final String name;
  final double budgeted;
  final double spent;
  final Color color;
  final IconData icon;

  Category({
    required this.name,
    required this.budgeted,
    required this.spent,
    required this.color,
    required this.icon,
  });

  double get percentage => budgeted > 0 ? (spent / budgeted) * 100 : 0;
  double get remaining => budgeted - spent;
}

class HomePage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final ThemeMode themeMode;

  const HomePage({
    super.key,
    required this.onThemeToggle,
    required this.themeMode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  List<Account> accounts = [];

  final List<Category> categories = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  // Load accounts from SharedPreferences
  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getStringList('accounts') ?? [];
    setState(() {
      accounts = accountsJson
          .map((jsonStr) => Account.fromMap(json.decode(jsonStr)))
          .toList();
    });
  }

  // Save accounts to SharedPreferences
  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = accounts
        .map((account) => json.encode(account.toMap()))
        .toList();
    await prefs.setStringList('accounts', accountsJson);
  }

  // Add new account
  void _addAccount(Account account) {
    setState(() {
      accounts.add(account);
    });
    _saveAccounts();
  }

  // Delete account
  void _deleteAccount(int index) {
    setState(() {
      accounts.removeAt(index);
    });
    _saveAccounts();
  }

  // Show add account dialog
  void _showAddAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAccountDialog(onAdd: _addAccount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? _buildHomePage()
          : _currentIndex == 1
          ? const CategoriesPage()
          : _currentIndex == 2
          ? BudgetPage(categories: categories)
          : const MonthlyExpenditureChart(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: const Color(0xFF2ECC71),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Charts'),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF2ECC71),
          actions: [
            IconButton(
              icon: Icon(
                widget.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: widget.onThemeToggle,
              tooltip: 'Toggle theme',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: const Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budgeter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                ),
              ],
            ),
            centerTitle: false,
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accounts and Budgets tabs
              _buildAccountsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsSection() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACCOUNTS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'BUDGETS & GOALS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of accounts header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'List of accounts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2ECC71)),
                  onPressed: _showAddAccountDialog,
                ),
              ],
            ),
          ),

          // Account cards grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: accounts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No accounts yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Account'),
                              content: Text(
                                'Are you sure you want to delete ${accounts[index].name}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _deleteAccount(index);
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: _buildAccountCard(accounts[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: account.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            account.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            account.balance >= 0
                ? 'UGX ${account.balance.toStringAsFixed(0)}'
                : '-UGX ${account.balance.abs().toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Categories Page
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final List<Category> budgetedCategories = [];

  final List<Map<String, dynamic>> nonBudgetedCategories = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  _buildTab('Spends', true),
                  const SizedBox(width: 20),
                  _buildTab('Categories', false),
                  const SizedBox(width: 20),
                  _buildTab('Merchants', false),
                ],
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donut chart
                _buildDonutChart(),

                const SizedBox(height: 30),

                // Budgeted categories
                _buildBudgetedCategories(),

                const SizedBox(height: 30),

                // Non-budgeted categories
                _buildNonBudgetedCategories(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isActive) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isActive
            ? Theme.of(context).textTheme.bodyLarge?.color
            : Colors.grey,
        decoration: isActive ? TextDecoration.underline : null,
        decorationColor: Theme.of(context).textTheme.bodyLarge?.color,
        decorationThickness: 2,
      ),
    );
  }

  Widget _buildDonutChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: budgetedCategories.isEmpty
              ? Center(
                  child: Text(
                    'No categories yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : CustomPaint(
                  painter: DonutChartPainter(categories: budgetedCategories),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total Spent',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBudgetedCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Budgeted categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: budgetedCategories.isEmpty ? 1 : budgetedCategories.length,
          itemBuilder: (context, index) {
            if (budgetedCategories.isEmpty) {
              return Center(
                child: Text(
                  'No budgeted categories',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              );
            }
            return _buildCategoryCard(budgetedCategories[index]);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Category category) {
    final percentage = (category.spent / category.budgeted * 100).clamp(
      0.0,
      100.0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${(budgetedCategories.indexOf(category) + 1) * 2}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: category.color,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: CircularProgressPainter(
                percentage: percentage,
                color: category.color,
              ),
              child: Center(
                child: Icon(category.icon, color: category.color, size: 28),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'UGX ${category.spent.toInt()} / ${category.budgeted.toInt()}',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildNonBudgetedCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Non-Budgeted categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        const SizedBox(height: 16),
        nonBudgetedCategories.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'No non-budgeted categories',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: nonBudgetedCategories.map((category) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: category['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category['name'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            Text(
                              '+${category['count']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: category['color'] as Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }
}

// Add Account Dialog
class AddAccountDialog extends StatefulWidget {
  final Function(Account) onAdd;

  const AddAccountDialog({super.key, required this.onAdd});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  Color _selectedColor = const Color(0xFF00BCD4);
  IconData _selectedIcon = Icons.account_balance_wallet;

  final List<Color> _colors = [
    const Color(0xFF00BCD4),
    const Color(0xFF9C27B0),
    const Color(0xFF2ECC71),
    const Color(0xFFFF9800),
    const Color(0xFF3F51B5),
    const Color(0xFFE91E63),
    const Color(0xFF4CAF50),
    const Color(0xFFF44336),
  ];

  final List<IconData> _icons = [
    Icons.account_balance_wallet,
    Icons.account_balance,
    Icons.savings,
    Icons.credit_card,
    Icons.payment,
    Icons.attach_money,
    Icons.monetization_on,
    Icons.local_atm,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _handleAdd() {
    if (_nameController.text.isEmpty || _balanceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final balance = double.tryParse(_balanceController.text);
    if (balance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final account = Account(
      name: _nameController.text,
      balance: balance,
      color: _selectedColor,
      icon: _selectedIcon,
    );

    widget.onAdd(account);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      title: Text(
        'Add Account',
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                labelText: 'Account Name',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey[isDark ? 600 : 400]!,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2ECC71)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                labelText: 'Balance',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixText: 'UGX ',
                prefixStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey[isDark ? 600 : 400]!,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2ECC71)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Color',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Icon',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2ECC71)
                          : (isDark ? Colors.grey[700] : Colors.grey[300]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black54),
                      size: 20,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: _handleAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Budget Page
class BudgetPage extends StatefulWidget {
  final List<Category> categories;

  const BudgetPage({super.key, required this.categories});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  @override
  Widget build(BuildContext context) {
    final total = widget.categories.fold<double>(
      0,
      (sum, cat) => sum + cat.spent,
    );
    final increase = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expenses structure card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expenses structure',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LAST 30 DAYS',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'UGX ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (increase != 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'vs past period',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${increase > 0 ? '+' : ''}$increase%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: increase > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Donut chart
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: widget.categories.isEmpty
                            ? Center(
                                child: Text(
                                  'No expenses yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              )
                            : CustomPaint(
                                painter: DonutChartPainter(
                                  categories: widget.categories,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'All',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        'UGX ${total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Monthly Expenditure Chart Screen
class MonthlyExpenditureChart extends StatefulWidget {
  const MonthlyExpenditureChart({super.key});

  @override
  State<MonthlyExpenditureChart> createState() =>
      _MonthlyExpenditureChartState();
}

class _MonthlyExpenditureChartState extends State<MonthlyExpenditureChart> {
  // Monthly data - empty by default, will be populated from actual expenses
  final Map<String, double> monthlyData = {};

  @override
  Widget build(BuildContext context) {
    final maxValue = monthlyData.isEmpty
        ? 100000.0
        : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final totalExpenditure = monthlyData.isEmpty
        ? 0.0
        : monthlyData.values.reduce((a, b) => a + b);
    final averageExpenditure = monthlyData.isEmpty
        ? 0.0
        : totalExpenditure / monthlyData.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monthly Expenditure',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Annual Expenditure',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'UGX ${totalExpenditure.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Average: UGX ${averageExpenditure.toStringAsFixed(0)}/month',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Chart Title
              const Text(
                'Monthly Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Bar Chart
              Container(
                height: 400,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: monthlyData.isEmpty
                    ? Center(
                        child: Text(
                          'No monthly data yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: BarChartPainter(
                          data: monthlyData,
                          maxValue: maxValue,
                          isDark: isDark,
                        ),
                        child: Container(),
                      ),
              ),
              const SizedBox(height: 24),

              // Monthly Details List
              if (monthlyData.isNotEmpty) ...[
                const Text(
                  'Detailed Monthly Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...monthlyData.entries.map((entry) {
                  final percentage = (entry.value / maxValue * 100)
                      .toStringAsFixed(0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'UGX ${entry.value.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: entry.value / maxValue,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[700],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2ECC71),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No monthly expenditure data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painters
class DonutChartPainter extends CustomPainter {
  final List<Category> categories;

  DonutChartPainter({required this.categories});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 25.0;

    final total = categories.fold<double>(0, (sum, cat) => sum + cat.spent);
    var startAngle = -math.pi / 2;

    for (final category in categories) {
      final sweepAngle = (category.spent / total) * 2 * math.pi;

      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircularProgressPainter extends CustomPainter {
  final double percentage;
  final Color color;

  CircularProgressPainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 6.0;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (percentage / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw sample data lines
    final linePaint1 = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final linePaint2 = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Sample paths
    final path1 = Path();
    final path2 = Path();

    final points1 = [0.7, 0.5, 0.6, 0.4, 0.5, 0.3, 0.4];
    final points2 = [0.6, 0.4, 0.5, 0.3, 0.4, 0.2, 0.25];

    for (var i = 0; i < points1.length; i++) {
      final x = size.width * i / (points1.length - 1);
      final y1 = size.height * points1[i];
      final y2 = size.height * points2[i];

      if (i == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
      }
    }

    canvas.drawPath(path1, linePaint1);
    canvas.drawPath(path2, linePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BarChartPainter extends CustomPainter {
  final Map<String, double> data;
  final double maxValue;
  final bool isDark;

  BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width - 80) / data.length;
    final chartHeight = size.height - 40;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.grey[700] : Colors.grey[300])!
      ..strokeWidth = 1;

    for (var i = 0; i <= 5; i++) {
      final y = (chartHeight / 5) * i;
      canvas.drawLine(Offset(40, y), Offset(size.width, y), gridPaint);

      // Draw y-axis labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(maxValue * (5 - i) / 5 / 1000).toStringAsFixed(0)}k',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // Draw bars
    var xOffset = 50.0;
    data.forEach((month, value) {
      final barHeight = (value / maxValue) * chartHeight;
      final barTop = chartHeight - barHeight;

      // Bar gradient
      final rect = Rect.fromLTWH(xOffset, barTop, barWidth - 10, barHeight);
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF2ECC71), const Color(0xFF27AE60)],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      // Draw rounded rectangle bar
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, paint);

      // Draw month label
      final monthPainter = TextPainter(
        text: TextSpan(
          text: month.substring(0, 1),
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      monthPainter.layout();
      monthPainter.paint(
        canvas,
        Offset(
          xOffset + (barWidth - 10) / 2 - monthPainter.width / 2,
          chartHeight + 10,
        ),
      );

      xOffset += barWidth;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
