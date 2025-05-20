import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('movies');
  final prefs = await SharedPreferences.getInstance();
  final isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
  runApp(MyApp(isDarkTheme: isDarkTheme));
}

class MyApp extends StatefulWidget {
  final bool isDarkTheme;
  MyApp({required this.isDarkTheme});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool isDarkTheme;

  @override
  void initState() {
    super.initState();
    isDarkTheme = widget.isDarkTheme;
  }

  void toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isDarkTheme = value);
    await prefs.setBool('isDarkTheme', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: MovieListScreen(onToggleTheme: toggleTheme, isDarkTheme: isDarkTheme),
    );
  }
}

class MovieListScreen extends StatefulWidget {
  final Function(bool) onToggleTheme;
  final bool isDarkTheme;
  MovieListScreen({required this.onToggleTheme, required this.isDarkTheme});
  @override
  _MovieListScreenState createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final Box movieBox = Hive.box('movies');

  void _addOrEditMovie({int? index, Map? existingMovie}) async {
    final titleController = TextEditingController(text: existingMovie?['title'] ?? '');
    final yearController = TextEditingController(text: existingMovie?['year'] ?? '');
    final genreController = TextEditingController(text: existingMovie?['genre'] ?? '');
    String? imagePath = existingMovie?['image'];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'Добавить фильм' : 'Редактировать фильм'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: titleController, decoration: InputDecoration(labelText: 'Название')),
              TextField(controller: yearController, decoration: InputDecoration(labelText: 'Год')),
              TextField(controller: genreController, decoration: InputDecoration(labelText: 'Жанр')),
              ElevatedButton(
                child: Text('Выбрать картинку'),
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => imagePath = picked.path);
                  }
                },
              ),
              if (imagePath != null) Image.file(File(imagePath!), height: 100),
            ],
          ),
        ),
        actions: [
          TextButton(child: Text('Отмена'), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: Text(index == null ? 'Добавить' : 'Сохранить'),
            onPressed: () {
              final newMovie = {
                'title': titleController.text,
                'year': yearController.text,
                'genre': genreController.text,
                'image': imagePath,
              };
              if (index == null) {
                movieBox.add(newMovie);
              } else {
                movieBox.putAt(index, newMovie);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
    setState(() {});
  }

  void _deleteMovie(int index) {
    movieBox.deleteAt(index);
    setState(() {});
  }@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Любимые фильмы'),
        actions: [
          Switch(
            value: widget.isDarkTheme,
            onChanged: widget.onToggleTheme,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: movieBox.listenable(),
        builder: (_, Box box, __) {
          if (box.isEmpty) return Center(child: Text('Нет фильмов'));
          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (_, index) {
              final movie = box.getAt(index);
              return ListTile(
                leading: movie['image'] != null
                    ? Image.file(File(movie['image']), width: 50, height: 50, fit: BoxFit.cover)
                    : Icon(Icons.movie),
                title: Text(movie['title']),
                subtitle: Text('${movie['year']} — ${movie['genre']}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: Icon(Icons.edit), onPressed: () => _addOrEditMovie(index: index, existingMovie: movie)),
                  IconButton(icon: Icon(Icons.delete), onPressed: () => _deleteMovie(index)),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _addOrEditMovie(),
      ),
    );
  }
}