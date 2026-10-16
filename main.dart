import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiKotibApp());
}

class AiKotibApp extends StatelessWidget {
  const AiKotibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Kotib — Xasan Zokirovich',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

class TaskItem {
  String id;
  String title;
  String deadline;
  String priority;
  String timestamp;
  String quote;
  String meetingTitle;
  String meetingDate;
  String? audioPath;
  bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    required this.deadline,
    required this.priority,
    required this.timestamp,
    required this.quote,
    required this.meetingTitle,
    required this.meetingDate,
    this.audioPath,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'deadline': deadline,
        'priority': priority,
        'timestamp': timestamp,
        'quote': quote,
        'meetingTitle': meetingTitle,
        'meetingDate': meetingDate,
        'audioPath': audioPath,
        'isCompleted': isCompleted,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] ?? UniqueKey().toString(),
        title: json['title'] ?? '',
        deadline: json['deadline'] ?? 'Muddat ko\'rsatilmagan',
        priority: json['priority'] ?? 'MEDIUM',
        timestamp: json['timestamp'] ?? '00:00',
        quote: json['quote'] ?? '',
        meetingTitle: json['meetingTitle'] ?? 'Yig\'ilish',
        meetingDate: json['meetingDate'] ?? '',
        audioPath: json['audioPath'],
        isCompleted: json['isCompleted'] ?? false,
      );
}

class MeetingRecord {
  String id;
  String title;
  String date;
  String summary;
  String transcript;
  List<String> generalNotes;
  String? audioPath;
  List<String> bookmarks;

  MeetingRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.summary,
    required this.transcript,
    required this.generalNotes,
    this.audioPath,
    required this.bookmarks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'summary': summary,
        'transcript': transcript,
        'generalNotes': generalNotes,
        'audioPath': audioPath,
        'bookmarks': bookmarks,
      };

  factory MeetingRecord.fromJson(Map<String, dynamic> json) => MeetingRecord(
        id: json['id'] ?? UniqueKey().toString(),
        title: json['title'] ?? 'Yig\'ilish',
        date: json['date'] ?? '',
        summary: json['summary'] ?? '',
        transcript: json['transcript'] ?? '',
        generalNotes: List<String>.from(json['generalNotes'] ?? []),
        audioPath: json['audioPath'],
        bookmarks: List<String>.from(json['bookmarks'] ?? []),
      );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isAnalyzing = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _currentAudioPath;
  final List<String> _currentBookmarks = [];

  List<TaskItem> _tasks = [];
  List<MeetingRecord> _meetings = [];
  String _apiKey = '';
  String _userProfile =
      'Ismim Xasan (Xasan Zokirovich Mamaziyayev). Samarqand iqtisodiyot va servis instituti (SamISI) Ekonometrika fani o\'qituvchisiman. O\'quv-uslubiy ishlar, dars jadvallari, ilmiy maqolalar, kafedra topshiriqlari, talabalar nazorati va raqamli iqtisodiyot loyihalari menga tegishli.';
  String _selectedModel = 'gemini-2.5-flash';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? '';
      _userProfile = prefs.getString('user_profile') ?? _userProfile;
      _selectedModel = prefs.getString('selected_model') ?? 'gemini-2.5-flash';

      final tasksJson = prefs.getStringList('tasks_list') ?? [];
      _tasks = tasksJson
          .map((e) => TaskItem.fromJson(jsonDecode(e)))
          .toList();

      final meetingsJson = prefs.getStringList('meetings_list') ?? [];
      _meetings = meetingsJson
          .map((e) => MeetingRecord.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', _apiKey);
    await prefs.setString('user_profile', _userProfile);
    await prefs.setString('selected_model', _selectedModel);

    final tasksJson = _tasks.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('tasks_list', tasksJson);

    final meetingsJson = _meetings.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('meetings_list', meetingsJson);
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _startRecording() async {
    if (_apiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, avval Sozlamalar bo\'limiga Gemini API kalitingizni kiriting!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _selectedIndex = 3);
      return;
    }

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofendan foydalanishga ruxsat berilmadi!')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/meeting_$timestamp.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
      ),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordDuration = 0;
      _currentAudioPath = filePath;
      _currentBookmarks.clear();
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  Future<void> _pauseResumeRecording() async {
    if (_isPaused) {
      await _audioRecorder.resume();
      _startTimer();
      setState(() => _isPaused = false);
    } else {
      await _audioRecorder.pause();
      _timer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  void _addBookmark() {
    final mark = _formatDuration(_recordDuration);
    if (!_currentBookmarks.contains(mark)) {
      setState(() => _currentBookmarks.add(mark));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📌 Muhim joy belgilandi: $mark'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _stopAndAnalyze() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (path != null && File(path).existsSync()) {
      await _analyzeAudioWithGemini(path);
    }
  }

  Future<void> _analyzeAudioWithGemini(String audioPath) async {
    setState(() => _isAnalyzing = true);

    try {
      final fileBytes = await File(audioPath).readAsBytes();
      final base64Audio = base64Encode(fileBytes);
      final todayStr = DateFormat('yyyy-MM-dd (EEEE)').format(DateTime.now());
      final bookmarksStr = _currentBookmarks.isEmpty
          ? 'Maxsus belgilangan daqiqalar yo\'q'
          : 'Foydalanuvchi yig\'ilish davomida quyidagi daqiqalarni MUHIM deb belgiladi: ${_currentBookmarks.join(", ")}';

      final systemPrompt = 'Siz professional AI-kotib va topshiriqlar tahlilchisisiz.\n'
          'Bugungi aniq sana: $todayStr.\n'
          'Foydalanuvchi profili (roli): $_userProfile\n'
          '$bookmarksStr\n\n'
          'VAZIFANGIZ:\n'
          '1. Yuborilgan yig\'ilish audiosini diqqat bilan eshiting (o\'zbek va rus tillaridagi aralash atamalarni to\'g\'ri tushuning).\n'
          '2. Suhbat ichidan aynan foydalanuvchiga tegishli yoki u bajarishi zarur bo\'lgan BARCHA reja, vazifa va topshiriqlarni saralab oling.\n'
          '3. Agar muddat "ertaga", "kelasi payshanbagacha", "oy oxirigacha", "3 kundan keyin" kabi nisbiy aytilgan bo\'lsa, bugungi sanadan ($todayStr) kelib chiqib, uni ANIQ KALENDAR SANASIGA (YYYY-MM-DD formatida) o\'giring. Agar umuman muddat aytilmagan bo\'lsa, mantiqiy yaqin muddatni (YYYY-MM-DD) qo\'ying.\n'
          '4. Javobni FAQAT quyidagi JSON formatda qaytaring:\n'
          '{\n'
          '  "meeting_title": "Yig\'ilishning qisqa va aniq nomi",\n'
          '  "short_summary": "Yig\'ilishning asosiy mazmuni (3-4 gapda)",\n'
          '  "transcript_excerpt": "Yig\'ilishda aytilgan eng muhim gaplarning matnga aylantirilgan stenogrammasi",\n'
          '  "my_tasks": [\n'
          '    {\n'
          '      "title": "Qilinishi kerak bo\'lgan aniq vazifa (qadam-baqadam va tushunarli tilda)",\n'
          '      "deadline": "YYYY-MM-DD",\n'
          '      "priority": "HIGH",\n'
          '      "timestamp": "MM:SS",\n'
          '      "quote": "Audioda bu haqda aytilgan aniq jumla"\n'
          '    }\n'
          '  ],\n'
          '  "general_notes": [\n'
          '    "Ma\'lumot uchun aytilgan umumiy yangilik yoki qarorlar"\n'
          '  ]\n'
          '}';

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=${_apiKey.trim()}');

      final requestBody = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": systemPrompt},
              {
                "inline_data": {
                  "mime_type": "audio/mp4",
                  "data": base64Audio
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.2,
          "responseMimeType": "application/json"
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final textContent =
            decoded['candidates'][0]['content']['parts'][0]['text'];
        final Map<String, dynamic> resultJson = jsonDecode(textContent);

        final meetingTitle =
            resultJson['meeting_title'] ?? 'Yig\'ilish tahlili';
        final meetingDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

        final newMeeting = MeetingRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: meetingTitle,
          date: meetingDate,
          summary: resultJson['short_summary'] ?? '',
          transcript: resultJson['transcript_excerpt'] ?? '',
          generalNotes: List<String>.from(resultJson['general_notes'] ?? []),
          audioPath: audioPath,
          bookmarks: List<String>.from(_currentBookmarks),
        );

        final List<dynamic> rawTasks = resultJson['my_tasks'] ?? [];
        final List<TaskItem> extractedTasks = rawTasks.map((t) {
          return TaskItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey()}',
            title: t['title'] ?? 'Yangi topshiriq',
            deadline: t['deadline'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
            priority: (t['priority'] ?? 'MEDIUM').toString().toUpperCase(),
            timestamp: t['timestamp'] ?? '00:00',
            quote: t['quote'] ?? '',
            meetingTitle: meetingTitle,
            meetingDate: meetingDate,
            audioPath: audioPath,
          );
        }).toList();

        setState(() {
          _meetings.insert(0, newMeeting);
          _tasks.insertAll(0, extractedTasks);
          _isAnalyzing = false;
          _selectedIndex = 1;
        });

        await _saveData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Tahlil yakunlandi! ${extractedTasks.length} ta topshiriq ajratib olindi.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        throw Exception('API xatosi (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tahlilda xatolik yuz berdi'),
            content: SingleChildScrollView(child: Text(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tushunarli'),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _playAudioAt(String? path, String timestamp) async {
    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio fayl topilmadi.')),
      );
      return;
    }

    int seconds = 0;
    try {
      final parts = timestamp.split(':');
      if (parts.length == 2) {
        seconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (_) {}

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
    if (seconds > 0) {
      await _audioPlayer.seek(Duration(seconds: seconds));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔊 Audio eshittirilmoqda ($timestamp dan)...'),
          action: SnackBarAction(
            label: 'To\'xtatish',
            onPressed: () => _audioPlayer.stop(),
          ),
        ),
      );
    }
  }

  void _showAddManualTextDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matndan topshiriq ajratish'),
        content: TextField(
          controller: textController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText:
                'Yig\'ilish matni yoki Telegramdan kelgan xabarni shu yerga tashlang...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textController.text.trim().isNotEmpty) {
                _analyzeTextWithGemini(textController.text.trim());
              }
            },
            child: const Text('Tahlil qilish'),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeTextWithGemini(String inputText) async {
    if (_apiKey.trim().isEmpty) {
      setState(() => _selectedIndex = 3);
      return;
    }
    setState(() => _isAnalyzing = true);
    try {
      final todayStr = DateFormat('yyyy-MM-dd (EEEE)').format(DateTime.now());
      final prompt = 'Bugungi sana: $todayStr.\n'
          'Foydalanuvchi profili: $_userProfile\n'
          'Quyidagi matndan foydalanuvchi bajarishi kerak bo\'lgan topshiriqlarni va muddatlarni JSON formatda ajratib bering:\n'
          'Matn: $inputText\n\n'
          'JSON qolipi:\n'
          '{\n'
          '  "meeting_title": "Mavzu nomi",\n'
          '  "short_summary": "Qisqa mazmuni",\n'
          '  "transcript_excerpt": "Matn",\n'
          '  "my_tasks": [\n'
          '    {\n'
          '      "title": "Aniq topshiriq",\n'
          '      "deadline": "YYYY-MM-DD",\n'
          '      "priority": "HIGH",\n'
          '      "timestamp": "00:00",\n'
          '      "quote": "Asos bo\'lgan jumla"\n'
          '    }\n'
          '  ],\n'
          '  "general_notes": []\n'
          '}';

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=${_apiKey.trim()}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json"
          }
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final textContent =
            decoded['candidates'][0]['content']['parts'][0]['text'];
        final Map<String, dynamic> resultJson = jsonDecode(textContent);

        final meetingTitle = resultJson['meeting_title'] ?? 'Matnli tahlil';
        final meetingDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

        final List<dynamic> rawTasks = resultJson['my_tasks'] ?? [];
        final List<TaskItem> extractedTasks = rawTasks.map((t) {
          return TaskItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey()}',
            title: t['title'] ?? 'Topshiriq',
            deadline: t['deadline'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
            priority: (t['priority'] ?? 'MEDIUM').toString().toUpperCase(),
            timestamp: t['timestamp'] ?? '00:00',
            quote: t['quote'] ?? '',
            meetingTitle: meetingTitle,
            meetingDate: meetingDate,
          );
        }).toList();

        setState(() {
          _tasks.insertAll(0, extractedTasks);
          _isAnalyzing = false;
          _selectedIndex = 1;
        });
        await _saveData();
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildRecorderTab(),
      _buildTasksTab(),
      _buildMeetingsTab(),
      _buildSettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Kotib & Diktofon',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Matndan topshiriq ajratish',
            icon: const Icon(Icons.post_add),
            onPressed: _showAddManualTextDialog,
          ),
        ],
      ),
      body: _isAnalyzing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 4),
                    const SizedBox(height: 24),
                    Text(
                      'Gemini AI yig\'ilish audiosini tahlil qilmoqda...',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Topshiriqlar saralanib, muddatlar hisoblanmoqda.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Diktofon',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _tasks.where((t) => !t.isCompleted).isNotEmpty,
              label: Text('${_tasks.where((t) => !t.isCompleted).length}'),
              child: const Icon(Icons.task_alt),
            ),
            label: 'Topshiriqlar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Yig\'ilishlar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Sozlamalar',
          ),
        ],
      ),
    );
  }

  Widget _buildRecorderTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Faol filtr: Xasan Zokirovich uchun kerakli topshiriqlar va muddatlarni avtomatik ajratish',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording
                ? (_isPaused ? '⏸ Vaqtincha to\'xtatildi' : '🔴 Yig\'ilish yozib olinmoqda...')
                : 'Yig\'ilishni yozish uchun tugmani bosing',
            style: TextStyle(
              fontSize: 16,
              color: _isRecording ? Colors.redAccent : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          if (_currentBookmarks.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _currentBookmarks
                  .map((b) => Chip(
                        avatar: const Icon(Icons.bookmark, size: 16),
                        label: Text(b),
                      ))
                  .toList(),
            ),
          const Spacer(),
          if (!_isRecording)
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 52),
              ),
            )
          else
            Column(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _addBookmark,
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('📌 Muhim joyni belgilash (Bookmark)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.large(
                      heroTag: 'pause_btn',
                      onPressed: _pauseResumeRecording,
                      child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    ),
                    FloatingActionButton.large(
                      heroTag: 'stop_btn',
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      onPressed: _stopAndAnalyze,
                      child: const Icon(Icons.stop),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'Hozircha topshiriqlar yo\'q.\nYig\'ilishni yozib oling yoki yuqoridagi tugma orqali matn kiriting.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        Color priorityColor = Colors.blue;
        if (task.priority == 'HIGH') priorityColor = Colors.redAccent;
        if (task.priority == 'LOW') priorityColor = Colors.green;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (val) {
                        setState(() => task.isCompleted = val ?? false);
                        _saveData();
                      },
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        setState(() => _tasks.removeAt(index));
                        _saveData();
                      },
                    ),
                  ],
                ),
                if (task.quote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(
                      '💬 "${task.quote}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        '⏳ Muddat: ${task.deadline}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      backgroundColor: priorityColor.withOpacity(0.15),
                      label: Text(
                        task.priority,
                        style: TextStyle(
                          fontSize: 11,
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (task.audioPath != null)
                      ActionChip(
                        avatar: const Icon(Icons.play_circle_outline, size: 18),
                        label: Text(task.timestamp),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _playAudioAt(task.audioPath, task.timestamp),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeetingsTab() {
    if (_meetings.isEmpty) {
      return const Center(
        child: Text(
          'Saqlangan yig\'ilish bayonnomalari yo\'q.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _meetings.length,
      itemBuilder: (context, index) {
        final m = _meetings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              m.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(m.date),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '📌 Qisqacha xulosa (Summary):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(m.summary),
              if (m.generalNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📋 Umumiy eslatmalar:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...m.generalNotes.map((n) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('• $n'),
                      ),
                    )),
              ],
              if (m.transcript.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📝 Stenogrammadan parcha:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m.transcript,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (m.audioPath != null)
                    TextButton.icon(
                      onPressed: () => _playAudioAt(m.audioPath, '00:00'),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Audioni eshitish'),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _meetings.removeAt(index));
                      _saveData();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('O\'chirish'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    final apiKeyCtrl = TextEditingController(text: _apiKey);
    final profileCtrl = TextEditingController(text: _userProfile);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '1. Gemini API Kaliti (Bepul)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kalitni aistudio.google.com saytidan bepul olib, shu yerga joylashtiring:',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: apiKeyCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'AIzaSy...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key),
          ),
          onChanged: (v) => _apiKey = v,
        ),
        const SizedBox(height: 20),
        const Text(
          '2. AI Modelni tanlash',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedModel,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(
              value: 'gemini-2.5-flash',
              child: Text('Gemini 2.5 Flash (Tezkor va tavsiya etiladi)'),
            ),
            DropdownMenuItem(
              value: 'gemini-2.5-pro',
              child: Text('Gemini 2.5 Pro (Chuqur tahlil uchun)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedModel = val);
              _saveData();
            }
          },
        ),
        const SizedBox(height: 20),
        const Text(
          '3. Mening rolim va mas\'uliyatlarim (AI filtri uchun)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),
        const Text(
          'AI yig\'ilishdagi yuzlab gaplar ichidan aynan sizga tegishlilarini ajratib olishi uchun o\'zingiz haqingizdagi ma\'lumot:',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: profileCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _userProfile = v,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            await _saveData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Sozlamalar saqlandi!')),
              );
            }
          },
          icon: const Icon(Icons.save),
          label: const Text('Sozlamalarni saqlash'),
        ),
      ],
    );
  }
}
