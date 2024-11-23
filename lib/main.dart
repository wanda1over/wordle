import 'dart:math'; // Для использования pi
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/services.dart'; // Для обработки ввода с клавиатуры
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordle Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wordle Game'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GameScreen()),
                );
              },
              child: Text('Играть'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StatisticsScreen()),
                );
              },
              child: Text('Статистика'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  String currentWord = "";
  List<String> wordsList = [];
  List<List<String>> grid = List.generate(6, (index) => List.filled(5, ""));
  int currentGuessIndex = 0;
  int currentLetterIndex = 0;
  String message = "";
  Map<String, Color> keyColors = {};

  late List<List<AnimationController>> animationControllers;
  late List<List<Animation<double>>> animations;

  // Добавляем контроллер и анимацию для тряски строки
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Добавляем focusNode для RawKeyboardListener
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadWordsFromFile();

    // Инициализируем контроллеры и анимации для переворота плиток
    animationControllers = List.generate(6, (i) {
      return List.generate(5, (j) {
        return AnimationController(
          duration: Duration(milliseconds: 300),
          vsync: this,
        );
      });
    });

    animations = List.generate(6, (i) {
      return List.generate(5, (j) {
        return Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: animationControllers[i][j],
            curve: Curves.easeInOut,
          ),
        );
      });
    });

    // Инициализируем контроллер и анимацию тряски строки
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reset();
        }
      });
  }

  @override
  void dispose() {
    // Утилизируем контроллеры анимации
    for (var row in animationControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadWordsFromFile() async {
    try {
      final contents = await rootBundle.loadString('assets/words.txt');
      setState(() {
        // Фильтруем слова, чтобы оставить только те, которые состоят из 5 букв
        wordsList = contents
            .split('\n')
            .where((word) => word.trim().length == 5)
            .map((word) => word.trim().
toLowerCase())
            .toList();
        _selectRandomWord();
      });
    } catch (e) {
      print('Ошибка при чтении файла: $e');
    }
  }

  void _selectRandomWord() {
    if (wordsList.isNotEmpty) {
      currentWord = (wordsList..shuffle()).first.trim().toLowerCase();
      print('Загаданное слово: $currentWord'); // Для отладки
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    // Обработка ввода с физической клавиатуры
    if (event is RawKeyDownEvent) {
      String key = event.data.logicalKey.keyLabel.toLowerCase();
      if (key.length == 1 && key.contains(RegExp(r'[а-яa-z]'))) {
        _onKeyPress(key);
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _onEnter();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _onDelete();
      }
    }
  }

  void _onKeyPress(String letter) {
    letter = letter.toLowerCase(); // Приводим к нижнему регистру
    setState(() {
      if (currentLetterIndex < 5 && currentGuessIndex < 6) {
        grid[currentGuessIndex][currentLetterIndex] = letter;
        currentLetterIndex++;
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (currentLetterIndex > 0) {
        currentLetterIndex--;
        grid[currentGuessIndex][currentLetterIndex] = "";
      }
    });
  }

  void _onEnter() {
    if (currentLetterIndex == 5) {
      String guess = grid[currentGuessIndex].join("");
      if (!wordsList.contains(guess)) {
        setState(() {
          message = "Слово должно быть настоящим и состоять из 5 букв!";
        });
        _shakeRow(); // Запускаем анимацию тряски
        return;
      }

      // Запускаем анимацию плиток
      for (int i = 0; i < 5; i++) {
        Future.delayed(Duration(milliseconds: i * 300), () {
          animationControllers[currentGuessIndex][i].forward();
        });
      }

      // Обновляем состояние после завершения анимации
      Future.delayed(Duration(milliseconds: 1500), () {
        setState(() {
          for (int i = 0; i < 5; i++) {
            String letter = guess[i];
            if (currentWord[i] == letter) {
              keyColors[letter] = Colors.green;
            } else if (currentWord.contains(letter)) {
              if (keyColors[letter] != Colors.green) {
                keyColors[letter] = Colors.orange;
              }
            } else {
              keyColors[letter] = Colors.grey;
            }
          }

          if (guess == currentWord) {
            message = "Поздравляем! Вы угадали слово!";
            _updateStatistics(true);
            _showEndGameDialog(true);
          } else if (currentGuessIndex >= 5) {
            message = "Вы исчерпали попытки. Загаданное слово: $currentWord";
            _updateStatistics(false);
            _showEndGameDialog(false);
          } else {
            currentGuessIndex++;
            currentLetterIndex = 0;
            message = "";
          }
        });
      });
    }
  }

  void _updateStatistics(bool didWin) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (didWin) {
      int wins = prefs.getInt('wins') ?? 0;
      prefs.setInt('wins', wins + 1);
    } else {
      int losses = prefs.getInt('losses') ?? 0;
      prefs.setInt('losses', losses + 1);
    }
  }

  void _resetGame() {
    setState(() {
      grid = List.generate(6, (index) => List.filled(5, ""));
      currentGuessIndex = 0;
      currentLetterIndex = 0;
      message = "";
      keyColors.clear();
      _selectRandomWord();

      // Сбрасываем контроллеры анимации
      for (var row in animationControllers) {
        for (var controller in row) {
          controller.reset();
        }
      }
    });
  }

  void _showEndGameDialog(bool didWin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(didWin ? 'Победа!' : 'Вы проиграли'),
          content: Text(
              didWin ? 'Вы угадали слово!' : 'Загаданное слово: $currentWord'),
          actions: [
TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
              child: Text('Играть снова'),
            ),
          ],
        );
      },
    );
  }

  // Метод для анимации тряски строки
  void _shakeRow() {
    _shakeController.forward();
  }

  Widget _buildGrid() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            double offset = 0;
            if (i == currentGuessIndex) {
              offset = _shakeAnimation.value;
            }
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (j) {
              return AnimatedBuilder(
                animation: animations[i][j],
                builder: (context, child) {
                  double value = animations[i][j].value;
                  double angle = 0;
                  Color cellColor = Colors.white;
                  String letter = grid[i][j];

                  if (value >= 0.5 && i <= currentGuessIndex) {
                    // После половины анимации (после 90 градусов)
                    angle = (1 - value) * pi;
                    // Определяем цвет плитки
                    if (currentWord[j] == letter) {
                      cellColor = Colors.green;
                    } else if (currentWord.contains(letter)) {
                      cellColor = Colors.orange;
                    } else {
                      cellColor = Colors.grey;
                    }
                  } else {
                    // До половины анимации (до 90 градусов)
                    angle = value * pi;
                  }

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(angle),
                    alignment: Alignment.center,
                    child: Container(
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        color: cellColor,
                      ),
                      height: 50,
                      width: 50,
                      child: Center(
                        child: letter != ''
                            ? Text(
                                letter.toUpperCase(),
                                style: TextStyle(fontSize: 24),
                              )
                            : Container(),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    const List<String> keys = [
      'Й',
      'Ц',
      'У',
      'К',
      'Е',
      'Н',
      'Г',
      'Ш',
      'Щ',
      'З',
      'Х',
      'Ъ',
      'Ф',
      'Ы',
      'В',
      'А',
      'П',
      'Р',
      'О',
      'Л',
      'Д',
      'Ж',
      'Э',
      'Я',
      'Ч',
      'С',
      'М',
      'И',
      'Т',
      'Ь',
      'Б',
      'Ю'
    ];

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: keys.map((letter) {
            return Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      keyColors[letter.toLowerCase()] ?? Colors.white,
                  minimumSize: Size(40, 50),
                ),
                onPressed: () => _onKeyPress(letter.toLowerCase()),
                child: Text(letter),
              ),
            );
          }).toList(),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _onEnter,
              child: Text('Ввод'),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _onDelete,
              child: Icon(Icons.backspace),
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Wordle на русском'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGrid(),
            SizedBox(height: 20),
            _buildKeyboard(),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int wins = 0;
  int losses = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      wins = prefs.getInt('wins') ?? 0;
      losses = prefs.getInt('losses') ?? 0;
    });
  }

  double get winPercentage {
    int totalGames = wins + losses;
    return totalGames > 0 ? (wins / totalGames) * 100 : 0.0;
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 200, // Ограничиваем высоту диаграммы
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: wins.toDouble(),
              color: Colors.green,
              title: 'Выигрыши: $wins',
            ),
            PieChartSectionData(
              value: losses.toDouble(),
              color: Colors.red,
              title: 'Проигрыши: $losses',
            ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Статистика'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Количество выигрышей: $wins'),
            Text('Количество проигрышей: $losses'),
            Text('Процент выигрыша: ${winPercentage.toStringAsFixed(2)}%'),
            SizedBox(height: 20),
            _buildPieChart(),
          ],
        ),
      ),
    );
  }
}
