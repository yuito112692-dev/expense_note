import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('expenseBox');
  await Hive.openBox('initialMoneyBox');
  runApp(const MyApp());
}

final myBox = Hive.box('expenseBox');
final initialMoneyBox = Hive.box('initialMoneyBox');

void saveData(DateTime date, int amount, String category) {
  final expense = {
    'date': date.toIso8601String(),
    'amount': amount,
    'category': category,
  };
  myBox.add(expense);
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
      content:Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          TextField(
            controller: _initialMoneyController,
            decoration: const InputDecoration(
              labelText: '初期金額',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20.0),
          OutlinedButton(
            onPressed: () {
              final initialMoney = int.tryParse(_initialMoneyController.text) ?? 0;
              initialMoneyBox.put('initialMoney', initialMoney);
              initialMoneyBox.put('initialDate', DateTime.now().toIso8601String());
              Navigator.of(context).pop();
              setState(() {});
            },
            child: const Text('保存'),
          ),
        ],
      )
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
    return  MaterialApp(
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
            side: BorderSide(
              color: const Color.fromARGB(255, 139, 203, 255),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!initialMoneyBox.containsKey('initialMoney')) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const InitialMoneyDialog();
          }
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
      )
    );
  }
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {

  @override
  Widget build(BuildContext context) {

    final DateTime now = DateTime.now();
    final int currentYear = now.year;
    final int currentMonth = now.month;

    final records = myBox.values.whereType<Map>().cast<Map>().toList();
    final thisYearRecords = records.where((item) {
      final date = DateTime.parse(item['date']);
      return date.year == currentYear;
    }).toList();
    final thisMonthRecords = thisYearRecords.where((item) {
      final date = DateTime.parse(item['date']);
      return date.month == currentMonth;
    }).toList();

    final int initialMoney = (initialMoneyBox.get('initialMoney') as int?) ?? 0;
    final String initialDate = ((initialMoneyBox.get('initialDate') as String?) ?? '').split('T')[0];

    final int totalBalance = records.fold(0, (sum, item) {
      final amount = item['amount'];
      if (amount is int) {
        return sum + amount;
      }
      return sum;
    });
    final int thisYearBalance = thisYearRecords.fold(0, (sum, item) {
      final amount = item['amount'];
      if (amount is int) {
        return sum + amount;
      }
      return sum;
    });
    final int thisMonthBalance = thisMonthRecords.fold(0, (sum, item) {
      final amount = item['amount'];
      if (amount is int) {
        return sum + amount;
      }
      return sum;
    });

    final int sum = totalBalance + initialMoney;

    return SingleChildScrollView(
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
            ValueListenableBuilder(
              valueListenable: myBox.listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty) {
                  return const Text('記録がありません');
                }
                return SingleChildScrollView(
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
                        box.length,
                        (index) {
                          final expense = box.getAt(box.length - 1 -index) as Map;
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
                );
              }
            ),
            const SizedBox(height: 30.0)
          ]
        ),
      ),
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
                  onPressed: () {
                    final amount = _sign == '+' ? int.parse(_amountController.text) : -int.parse(_amountController.text);
                    saveData(selectedDate, amount, _categoryController.text);
                    setState(() {
                      selectedDate = DateTime.now();
                      _amountController.clear();
                      _categoryController.clear();
                    });
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        )
      );
    });
  }
}