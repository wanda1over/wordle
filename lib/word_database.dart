// Импорт библиотеки localstorage для работы с локальным хранилищем данных.
import 'package:localstorage/localstorage.dart';
// Импорт библиотеки для генерации случайных чисел.
import 'dart:math';

// Класс для управления базой данных слов, реализованной с использованием localstorage.
class WordDatabase {
  // Синглтон для доступа к экземпляру класса.
  static final WordDatabase instance = WordDatabase._init();

  // Инициализация localstorage с названием 'words'.
  final LocalStorage storage = LocalStorage('words');

  // Приватный конструктор для реализации синглтона.
  WordDatabase._init();

  // Метод для инициализации базы данных.
  Future<void> initializeDatabase() async {
    // Ожидание готовности хранилища.
    await storage.ready;
    // Проверка, существует ли список слов. Если нет, то создаем новый список.
    if (storage.getItem('word_list') == null) {
      // Создаем список слов для игры.
      List<String> words = ['СЛОВО', 'ГРУША', 'ОЛОВО', 'СЛИВА', 'БАНАН'];
      // Сохраняем список слов в localstorage.
      storage.setItem('word_list', words);
    }
  }

  // Метод для получения случайного слова из списка.
  Future<String?> getRandomWord() async {
    // Ожидание готовности хранилища.
    await storage.ready;
    // Получаем список слов из localstorage.
    List<String>? words = storage.getItem('word_list');
    // Если список слов существует и не пустой, возвращаем случайное слово.
    if (words != null && words.isNotEmpty) {
      final randomIndex = Random().nextInt(words.length);
      return words[randomIndex];
    }
    // Если список пустой или не найден, возвращаем null.
    return null;
  }
}