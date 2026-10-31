import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'supabase_config.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-Do List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD88FA5),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF7F8),
        useMaterial3: true,
      ),
      home: const TodoPage(),
    );
  }
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _controller =
      TextEditingController();

  List<dynamic> _tasks = [];
  bool _loading = false;
  String? _error;

  Map<String, String> get _headers => {
        'apikey': publishableKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri get _tasksUrl => Uri.parse(
        '$supabaseUrl/rest/v1/tasks',
      );

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // GET: mengambil daftar tugas
  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        _tasksUrl.replace(
          queryParameters: {
            'select': '*',
            'order': 'id.desc',
          },
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          _tasks = jsonDecode(response.body) as List<dynamic>;
        });
      } else {
        throw Exception(
          'Gagal mengambil tugas (${response.statusCode}): '
          '${response.body}',
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // POST: menambahkan tugas
  Future<void> _addTask() async {
    final title = _controller.text.trim();

    if (title.isEmpty) {
      _showMessage('Nama tugas belum diisi.');
      return;
    }

    try {
      final response = await http.post(
        _tasksUrl,
        headers: {
          ..._headers,
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'title': title,
          'is_completed': false,
        }),
      );

      if (response.statusCode == 201 ||
          response.statusCode == 200) {
        _controller.clear();
        await _loadTasks();
        _showMessage('Tugas berhasil ditambahkan!');
      } else {
        throw Exception(
          'Gagal menambahkan tugas (${response.statusCode}): '
          '${response.body}',
        );
      }
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  // PATCH: mengubah status tugas
  Future<void> _toggleTask(
    int id,
    bool isCompleted,
  ) async {
    try {
      final response = await http.patch(
        _tasksUrl.replace(
          queryParameters: {'id': 'eq.$id'},
        ),
        headers: {
          ..._headers,
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'is_completed': isCompleted,
        }),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        await _loadTasks();
      } else {
        throw Exception(
          'Gagal mengubah tugas (${response.statusCode}): '
          '${response.body}',
        );
      }
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  // DELETE: menghapus tugas
  Future<void> _deleteTask(int id) async {
    try {
      final response = await http.delete(
        _tasksUrl.replace(
          queryParameters: {'id': 'eq.$id'},
        ),
        headers: _headers,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        await _loadTasks();
        _showMessage('Tugas berhasil dihapus.');
      } else {
        throw Exception(
          'Gagal menghapus tugas (${response.statusCode}): '
          '${response.body}',
        );
      }
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where(
      (task) => task['is_completed'] == true,
    ).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'To-Do List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFBF7F8),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catatan Kegiatan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$completedCount dari ${_tasks.length} tugas selesai',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Masukkan tugas baru...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD88FA5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(50, 50),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null && _tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off,
                                size: 42,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Data belum bisa dimuat.',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadTasks,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : _tasks.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada tugas. Yuk, tambahkan!',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTasks,
                              child: ListView.builder(
                                itemCount: _tasks.length,
                                itemBuilder: (context, index) {
                                  final task = _tasks[index];
                                  final id = task['id'] as int;
                                  final title =
                                      task['title'] as String;
                                  final completed =
                                      task['is_completed'] == true;

                                  return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.only(
                                      bottom: 10,
                                    ),
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: completed,
                                        activeColor:
                                            const Color(0xFFD88FA5),
                                        onChanged: (value) {
                                          if (value != null) {
                                            _toggleTask(id, value);
                                          }
                                        },
                                      ),
                                      title: Text(
                                        title,
                                        style: TextStyle(
                                          decoration: completed
                                              ? TextDecoration
                                                  .lineThrough
                                              : TextDecoration.none,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _deleteTask(id),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
