import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: publishableKey,
  );

  runApp(const TodoApp());
}

final supabase = Supabase.instance.client;

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
      home: const AuthGate(),
    );
  }
}

// Menentukan halaman berdasarkan status login.
// Supabase akan memulihkan sesi yang tersimpan otomatis.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          return const LoginPage();
        }

        return const TodoPage();
      },
    );
  }
}

// ================= LOGIN =================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  String? errorMessage;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Email dan password harus diisi.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // AuthGate akan berpindah ke halaman To-Do List.
    } on AuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.task_alt,
                  size: 70,
                  color: Color(0xFFD88FA5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'To-Do List',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login untuk mengelola tugas kamu',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (_) => login(),
                ),
                const SizedBox(height: 16),

                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: loading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD88FA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= TO-DO LIST =================

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final taskController = TextEditingController();

  List<Map<String, dynamic>> tasks = [];
  bool loading = true;
  String? errorMessage;

  User get currentUser => supabase.auth.currentUser!;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  // GET: mengambil tugas milik user yang sedang login.
  Future<void> loadTasks() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await supabase
          .from('tasks')
          .select()
          .eq('user_id', currentUser.id)
          .order('id', ascending: false);

      setState(() {
        tasks = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal mengambil data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // POST: menambahkan tugas untuk user yang sedang login.
  Future<void> addTask() async {
    final title = taskController.text.trim();

    if (title.isEmpty) {
      showMessage('Nama tugas belum diisi.');
      return;
    }

    try {
      await supabase.from('tasks').insert({
        'title': title,
        'is_completed': false,
        'user_id': currentUser.id,
      });

      taskController.clear();
      await loadTasks();
      showMessage('Tugas berhasil ditambahkan.');
    } catch (e) {
      showMessage('Gagal menambahkan tugas: $e');
    }
  }

  // PATCH: mengubah status tugas.
  Future<void> toggleTask(
    int id,
    bool completed,
  ) async {
    try {
      await supabase
          .from('tasks')
          .update({'is_completed': completed})
          .eq('id', id)
          .eq('user_id', currentUser.id);

      await loadTasks();
    } catch (e) {
      showMessage('Gagal mengubah tugas: $e');
    }
  }

  // DELETE: menghapus tugas milik user.
  Future<void> deleteTask(int id) async {
    try {
      await supabase
          .from('tasks')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUser.id);

      await loadTasks();
      showMessage('Tugas berhasil dihapus.');
    } catch (e) {
      showMessage('Gagal menghapus tugas: $e');
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
      // AuthGate akan kembali menampilkan LoginPage.
    } catch (e) {
      showMessage('Gagal logout: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = tasks
        .where((task) => task['is_completed'] == true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'To-Do List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFBF7F8),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
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
              'Login sebagai: ${currentUser.email ?? '-'}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),

            Text(
              '$completedCount dari ${tasks.length} tugas selesai',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan tugas baru...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => addTask(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: addTask,
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
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: loadTasks,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : tasks.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada tugas. Yuk, tambahkan!',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: loadTasks,
                              child: ListView.builder(
                                itemCount: tasks.length,
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
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
                                            toggleTask(id, value);
                                          }
                                        },
                                      ),
                                      title: Text(
                                        title,
                                        style: TextStyle(
                                          decoration: completed
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => deleteTask(id),
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
