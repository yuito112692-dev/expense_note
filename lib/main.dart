import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabaseの初期化（ご自身のURLとAnon Keyに書き換えてください）
  await Supabase.initialize(
    url: 'https://yplhslkjnqozlgcdqjta.supabase.co',
    publishableKey: 'sb_publishable_IOtdC3lGOsfAY5puP6xqVg_nzs5oKy3',
  );

  // Hiveの初期化（過去データの移行元として使用）
  await Hive.initFlutter();
  await Hive.openBox('expenseBox');
  await Hive.openBox('initialMoneyBox');

  // 起動時にHiveからSupabaseへデータ移行を実行
  await migrateHiveToSupabase();

  runApp(const MyApp());
}

// HiveからSupabaseへデータを移行する関数
Future<void> migrateHiveToSupabase() async {
  final expenseBox = Hive.box('expenseBox');
  final initialMoneyBox = Hive.box('initialMoneyBox');

  // 1. 収支データの移行
  if (expenseBox.isNotEmpty) {
    final records = expenseBox.values.whereType<Map>().cast<Map>().toList();
    for (var item in records) {
      try {
        await Supabase.instance.client.from('expenses').insert({
          'date': item['date'],
          'amount': item['amount'],
          'category': item['category'],
        });
      } catch (e) {
        // すでに移行済みなどのエラーはスキップ
        debugPrint('Migration error (expense): $e');
      }
    }
    // 移行が終わったらローカルのHiveを空にする（重複を防ぐため）
    await expenseBox.clear();
  }

  // 2. 初期金額の移行
  if (initialMoneyBox.containsKey('initialMoney') && !initialMoneyBox.get('migratedToSupabase', defaultValue: false)) {
    final initialMoney = initialMoneyBox.get('initialMoney');
    final initialDate = initialMoneyBox.get('initialDate');

    try {
      await Supabase.instance.client.from('settings').upsert({
        'key': 'initialMoney',
        'value': initialMoney.toString(),
      });
      await Supabase.instance.client.from('settings').upsert({
        'key': 'initialDate',
        'value': initialDate.toString(),
      });

      // 移行完了フラグを立てる
      await initialMoneyBox.put('migratedToSupabase', true);
    } catch (e) {
      debugPrint('Migration error (settings): $e');
    }
  }
}

// Supabaseにデータを保存する関数
Future<void> saveData(DateTime date, int amount, String category) async {
  await Supabase.instance.client.from('expenses').insert({
    'date': date.toIso8601String(),
    'amount': amount,
    'category': category,
  });
}

class InitialMoneyDialog extends StatefulWidget {
  const InitialMoneyDialog({super.key});

  @override
  State<InitialMoneyDialog> createState() => _InitialMoneyDialogState();
}

class _InitialMoneyDialogState extends State<InitialMoneyDialog> {
  final TextEditingController _initialMoneyController = TextEditingController();

  @override
  void dispose() {
    _initialMoneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('初期金額を入力してください'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          TextField(
            controller: _initialMoneyController,
            decoration: const InputDecoration(
              labelText: '初期金額',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 20.0),
          OutlinedButton(
            onPressed: () async {
              final initialMoney = int.tryParse(_initialMoneyController.text) ?? 0;
              final initialDate = DateTime.now().toIso8601String();

              // Supabaseのsettingsテーブルに保存
              await Supabase.instance.client.from('settings').upsert({
                'key': 'initialMoney',
                'value': initialMoney.toString(),
              });
              await Supabase.instance.client.from('settings').upsert({
                'key': 'initialDate',
                'value': initialDate,
              });

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class DatePicker extends StatefulWidget {
  const DatePicker({super.key});

  @override
  State<DatePicker> createState() => _DatePickerState();
}

DateTime selectedDate = DateTime.now();

class _DatePickerState extends State<DatePicker> {
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text("${selectedDate.toLocal()}".split(' ')[0]),
        const SizedBox(width: 20.0),
        ElevatedButton(
          onPressed: () => _selectDate(context),
          child: const Text('Select date'),
        ),
      ],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainPage(),
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[350],
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            side: const BorderSide(
              color: Color.fromARGB(255, 139, 203, 255),
              width: 2.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const RecordPage(),
    const InputPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Supabaseから初期金額が設定されているか確認
      final response = await Supabase.instance.client
          .from('settings')
          .select()
          .eq('key', 'initialMoney')
          .maybeSingle();

      if (response == null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const InitialMoneyDialog();
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お小遣い帳'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '記録',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: '入力',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  // Supabaseからデータを取得するためのFutureメソッド
  Future<Map<String, dynamic>> _fetchData() async {
    final expensesResponse = await Supabase.instance.client
        .from('expenses')
        .select()
        .order('date', ascending: false);

    final settingsResponse = await Supabase.instance.client
        .from('settings')
        .select();

    int initialMoney = 0;
    String initialDate = '';

    for (var item in settingsResponse) {
      if (item['key'] == 'initialMoney') {
        initialMoney = int.tryParse(item['value'].toString()) ?? 0;
      } else if (item['key'] == 'initialDate') {
        initialDate = item['value'].toString().split('T')[0];
      }
    }

    return {
      'expenses': expensesResponse,
      'initialMoney': initialMoney,
      'initialDate': initialDate,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final data = snapshot.data ?? {};
        final records = (data['expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final int initialMoney = data['initialMoney'] ?? 0;
        final String initialDate = data['initialDate'] ?? '';

        final DateTime now = DateTime.now();
        final int currentYear = now.year;
        final int currentMonth = now.month;

        final thisYearRecords = records.where((item) {
          final date = DateTime.parse(item['date']);
          return date.year == currentYear;
        }).toList();

        final thisMonthRecords = thisYearRecords.where((item) {
          final date = DateTime.parse(item['date']);
          return date.month == currentMonth;
        }).toList();

        final int totalBalance = records.fold(0, (sum, item) {
          final amount = item['amount'];
          if (amount is int) return sum + amount;
          if (amount is num) return sum + amount.toInt();
          return sum;
        });

        final int thisYearBalance = thisYearRecords.fold(0, (sum, item) {
          final amount = item['amount'];
          if (amount is int) return sum + amount;
          if (amount is num) return sum + amount.toInt();
          return sum;
        });

        final int thisMonthBalance = thisMonthRecords.fold(0, (sum, item) {
          final amount = item['amount'];
          if (amount is int) return sum + amount;
          if (amount is num) return sum + amount.toInt();
          return sum;
        });

        final int sum = totalBalance + initialMoney;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30.0),
                  Text('合計：$sum'),
                  const SizedBox(height: 15.0),
                  Text('収支($initialDate～合計)：$totalBalance'),
                  const SizedBox(height: 10.0),
                  Text('収支(今年)：$thisYearBalance'),
                  const SizedBox(height: 10.0),
                  Text('収支(今月)：$thisMonthBalance'),
                  const SizedBox(height: 30.0),
                  records.isEmpty
                      ? const Text('記録がありません')
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('日付')),
                                DataColumn(label: Text('金額')),
                                DataColumn(label: Text('カテゴリ')),
                              ],
                              rows: List<DataRow>.generate(
                                records.length,
                                (index) {
                                  final expense = records[index];
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(expense['date'].toString().split('T')[0])),
                                      DataCell(Text(expense['amount'].toString())),
                                      DataCell(Text(expense['category'].toString())),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 30.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  String _sign = '+';

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _sign,
                  icon: const Icon(Icons.arrow_downward),
                  items: const [
                    DropdownMenuItem(
                      value: '+',
                      child: Text('収入'),
                    ),
                    DropdownMenuItem(
                      value: '-',
                      child: Text('支出'),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _sign = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 30.0),
                const DatePicker(),
                const SizedBox(height: 30.0),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: '金額',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                const SizedBox(height: 30.0),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 30.0),
                ElevatedButton(
                  onPressed: () async {
                    final rawAmount = int.tryParse(_amountController.text) ?? 0;
                    final amount = _sign == '+' ? rawAmount : -rawAmount;
                    
                    // Supabaseに保存
                    await saveData(selectedDate, amount, _categoryController.text);

                    setState(() {
                      selectedDate = DateTime.now();
                      _amountController.clear();
                      _categoryController.clear();
                    });

                    // 画面を再描画するため、親ウィジェット（MainPageやRecordPage）へ通知するか、
                    // 必要に応じてStatefulな構成を調整してください。
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}