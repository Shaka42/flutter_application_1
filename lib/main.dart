import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const NoterApp());
}

// Models
class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Color color;
  final String category;
  final bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.color,
    this.category = 'General',
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'color': color.toARGB32(),
        'category': category,
        'isPinned': isPinned,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        color: Color(json['color'] as int),
        category: json['category'] as String? ?? 'General',
        isPinned: json['isPinned'] as bool? ?? false,
      );

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    Color? color,
    String? category,
    bool? isPinned,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class VoiceNote {
  final String id;
  final String title;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;
  final Color color;

  VoiceNote({
    required this.id,
    required this.title,
    required this.filePath,
    required this.createdAt,
    required this.duration,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
      'title': title,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'duration': duration.inSeconds,
      'color': color.toARGB32(),
    };  factory VoiceNote.fromJson(Map<String, dynamic> json) => VoiceNote(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['filePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        duration: Duration(seconds: json['duration'] as int),
        color: Color(json['color'] as int),
      );
}

// Main App
class NoterApp extends StatefulWidget {
  const NoterApp({super.key});

  @override
  State<NoterApp> createState() => _NoterAppState();
}

class _NoterAppState extends State<NoterApp> {
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
      title: 'Noter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00D2FF),
          surface: Colors.white,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF2D3436),
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00D2FF),
          surface: const Color(0xFF1A1A2E),
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A2E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: _themeMode,
      home: HomePage(onThemeToggle: _toggleTheme, themeMode: _themeMode),
    );
  }
}

// Home Page
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
  List<Note> _textNotes = [];
  List<VoiceNote> _voiceNotes = [];
  bool _isGridView = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final Set<String> _customCategories = {};

  static const List<String> _defaultCategories = [
    'General',
    'Work',
    'Personal',
    'Ideas',
    'Tasks',
    'Reminders',
  ];

  List<String> get _noteCategories {
    final categories = {
      ..._defaultCategories,
      ..._customCategories,
      ..._textNotes.map((note) => note.category),
    }..removeWhere((category) => category.trim().isEmpty);
    final sorted = categories.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    _loadNotes();
    _loadViewPreference();
  }

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('customCategories');
    if (stored == null) {
      return;
    }
    final cleaned = stored
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    if (cleaned.isEmpty) {
      return;
    }
    setState(() {
      _customCategories
        ..clear()
        ..addAll(cleaned);
    });
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool('isGridView') ?? false;
    });
  }

  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = !_isGridView;
    });
    await prefs.setBool('isGridView', _isGridView);
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load text notes
    final textNotesJson = prefs.getString('textNotes');
    if (textNotesJson != null) {
      final List<dynamic> decoded = jsonDecode(textNotesJson);
      setState(() {
        _textNotes = decoded.map((json) => Note.fromJson(json)).toList();
      });
    }

    // Load voice notes
    final voiceNotesJson = prefs.getString('voiceNotes');
    if (voiceNotesJson != null) {
      final List<dynamic> decoded = jsonDecode(voiceNotesJson);
      setState(() {
        _voiceNotes = decoded.map((json) => VoiceNote.fromJson(json)).toList();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save text notes
    final textNotesJson = jsonEncode(_textNotes.map((n) => n.toJson()).toList());
    await prefs.setString('textNotes', textNotesJson);

    // Save voice notes
    final voiceNotesJson = jsonEncode(_voiceNotes.map((n) => n.toJson()).toList());
    await prefs.setString('voiceNotes', voiceNotesJson);
  }

  Future<void> _saveCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = _customCategories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await prefs.setStringList('customCategories', sorted);
  }

  void _addTextNote(Note note) {
    setState(() {
      _textNotes.insert(0, note);
    });
    _saveNotes();
  }

  void _updateTextNote(String id, Note updatedNote) {
    setState(() {
      final index = _textNotes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _textNotes[index] = updatedNote;
      }
    });
    _saveNotes();
  }

  void _deleteTextNote(String id) {
    setState(() {
      _textNotes.removeWhere((n) => n.id == id);
    });
    _saveNotes();
  }

  void _togglePinNote(String id) {
    setState(() {
      final index = _textNotes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _textNotes[index] = _textNotes[index].copyWith(
          isPinned: !_textNotes[index].isPinned,
          updatedAt: DateTime.now(),
        );
      }
    });
    _saveNotes();
  }

  List<Note> get _filteredNotes {
    var notes = _textNotes.where((note) {
      final searchLower = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(searchLower) ||
          note.content.toLowerCase().contains(searchLower);
    }).toList();

    if (_selectedCategory != 'All') {
      notes = notes.where((note) => note.category == _selectedCategory).toList();
    }

    // Sort: pinned first, then by date
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return notes;
  }

  void _handleCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _addCustomCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final lower = trimmed.toLowerCase();
    final existsInDefaults = _defaultCategories.any((c) => c.toLowerCase() == lower);
    final existsInCustoms = _customCategories.any((c) => c.toLowerCase() == lower);
    if (existsInDefaults || existsInCustoms) {
      return;
    }
    setState(() {
      _customCategories.add(trimmed);
    });
    _saveCustomCategories();
  }

  Future<void> _exportNotes() async {
    try {
      final notesData = {
        'textNotes': _textNotes.map((n) => n.toJson()).toList(),
        'voiceNotes': _voiceNotes.map((n) => n.toJson()).toList(),
        'exportDate': DateTime.now().toIso8601String(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(notesData);
      
      // For web, we'll show a dialog with the JSON
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Notes'),
            content: SingleChildScrollView(
              child: SelectableText(
                jsonString,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_textNotes.length} text notes and ${_voiceNotes.length} voice notes exported!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addVoiceNote(VoiceNote note) {
    setState(() {
      _voiceNotes.insert(0, note);
    });
    _saveNotes();
  }

  void _deleteVoiceNote(String id) async {
    final note = _voiceNotes.firstWhere((n) => n.id == id);
    final file = File(note.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _voiceNotes.removeWhere((n) => n.id == id);
    });
    _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          NotesListPage(
            textNotes: _filteredNotes,
            voiceNotes: _voiceNotes,
            onAddTextNote: _addTextNote,
            onUpdateTextNote: _updateTextNote,
            onDeleteTextNote: _deleteTextNote,
            onTogglePinNote: _togglePinNote,
            onAddVoiceNote: _addVoiceNote,
            onDeleteVoiceNote: _deleteVoiceNote,
            themeMode: widget.themeMode,
            onThemeToggle: widget.onThemeToggle,
            isGridView: _isGridView,
            onToggleView: _toggleViewMode,
            searchQuery: _searchQuery,
            onSearchChanged: (query) => setState(() => _searchQuery = query),
            onExport: _exportNotes,
            categories: _noteCategories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _handleCategorySelected,
            onCreateCategory: _addCustomCategory,
          ),
          VoiceNotesPage(
            voiceNotes: _voiceNotes,
            onAddVoiceNote: _addVoiceNote,
            onDeleteVoiceNote: _deleteVoiceNote,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedItemColor: const Color(0xFF6C5CE7),
            unselectedItemColor: Colors.grey[400],
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.note_rounded, size: 26),
                label: 'Notes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.mic_rounded, size: 26),
                label: 'Voice Notes',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showAddNoteDialog(context),
              backgroundColor: const Color(0xFF6C5CE7),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddEditNoteDialog(
        onSave: _addTextNote,
        categories: _noteCategories,
        onCreateCategory: _addCustomCategory,
      ),
    );
  }
}

// Notes List Page
class NotesListPage extends StatelessWidget {
  final List<Note> textNotes;
  final List<VoiceNote> voiceNotes;
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final Function(String) onCreateCategory;
  final Function(Note) onAddTextNote;
  final Function(String, Note) onUpdateTextNote;
  final Function(String) onDeleteTextNote;
  final Function(String) onTogglePinNote;
  final Function(VoiceNote) onAddVoiceNote;
  final Function(String) onDeleteVoiceNote;
  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;
  final bool isGridView;
  final VoidCallback onToggleView;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onExport;

  const NotesListPage({
    super.key,
    required this.textNotes,
    required this.voiceNotes,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  required this.onCreateCategory,
    required this.onAddTextNote,
    required this.onUpdateTextNote,
    required this.onDeleteTextNote,
    required this.onTogglePinNote,
    required this.onAddVoiceNote,
    required this.onDeleteVoiceNote,
    required this.themeMode,
    required this.onThemeToggle,
    required this.isGridView,
    required this.onToggleView,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    final totalNotes = textNotes.length + voiceNotes.length;
    final displayCategories = ['All', ...categories];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF6C5CE7), const Color(0xFF00D2FF)]
                    : [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Noter',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '$totalNotes ${totalNotes == 1 ? 'note' : 'notes'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 24),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: Icon(
                  isGridView ? Icons.view_list : Icons.grid_view,
                  color: Colors.white,
                ),
                onPressed: onToggleView,
                tooltip: 'Toggle view',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: onExport,
                tooltip: 'Export notes',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: Colors.white,
                ),
                onPressed: onThemeToggle,
                tooltip: 'Toggle theme',
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6C5CE7)),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => onSearchChanged(''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = displayCategories[index];
                      final isSelected = category == selectedCategory;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) => onCategorySelected(category),
                        selectedColor: const Color(0xFF6C5CE7),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : const Color(0xFF2D3436)),
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor:
                            isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF6C5CE7)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (textNotes.isEmpty && voiceNotes.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 40),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.note_add_rounded,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notes yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to create your first note',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  isGridView
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: textNotes.length,
                          itemBuilder: (context, index) {
                            final note = textNotes[index];
                            return Dismissible(
                              key: Key(note.id),
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(Icons.push_pin, color: Colors.white),
                              ),
                              secondaryBackground: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  onTogglePinNote(note.id);
                                  return false;
                                } else {
                                  return await _showDeleteConfirmation(context);
                                }
                              },
                              onDismissed: (direction) {
                                if (direction == DismissDirection.endToStart) {
                                  onDeleteTextNote(note.id);
                                }
                              },
                              child: NoteCard(
                                note: note,
                                onTap: () => _showEditNoteDialog(context, note),
                                onDelete: () => onDeleteTextNote(note.id),
                                onTogglePin: () => onTogglePinNote(note.id),
                              ),
                            );
                          },
                        )
                      : Column(
                          children: textNotes.map((note) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Dismissible(
                              key: Key(note.id),
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(Icons.push_pin, color: Colors.white),
                              ),
                              secondaryBackground: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  onTogglePinNote(note.id);
                                  return false;
                                } else {
                                  return await _showDeleteConfirmation(context);
                                }
                              },
                              onDismissed: (direction) {
                                if (direction == DismissDirection.endToStart) {
                                  onDeleteTextNote(note.id);
                                }
                              },
                              child: NoteCard(
                                note: note,
                                onTap: () => _showEditNoteDialog(context, note),
                                onDelete: () => onDeleteTextNote(note.id),
                                onTogglePin: () => onTogglePinNote(note.id),
                              ),
                            ),
                          )).toList(),
                        ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showEditNoteDialog(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => AddEditNoteDialog(
        note: note,
        onSave: (updatedNote) => onUpdateTextNote(note.id, updatedNote),
        categories: categories,
        onCreateCategory: onCreateCategory,
      ),
    );
  }
}

// Note Card Widget
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: note.color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    if (note.isPinned)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: const Icon(
                          Icons.push_pin,
                          size: 16,
                          color: Color(0xFF6C5CE7),
                        ),
                      ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: note.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'pin') {
                          onTogglePin();
                        } else if (value == 'delete') {
                          _confirmDelete(context);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(
                                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(note.isPinned ? 'Unpin' : 'Pin'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      child: const Icon(Icons.more_vert, size: 20),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: note.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                note.category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: note.color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              note.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Add/Edit Note Dialog
class AddEditNoteDialog extends StatefulWidget {
  final Note? note;
  final Function(Note) onSave;
  final List<String> categories;
  final Function(String) onCreateCategory;

  const AddEditNoteDialog({
    super.key,
    this.note,
    required this.onSave,
    required this.categories,
    required this.onCreateCategory,
  });

  @override
  State<AddEditNoteDialog> createState() => _AddEditNoteDialogState();
}

class _AddEditNoteDialogState extends State<AddEditNoteDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _newCategoryController;
  late Color _selectedColor;
  late String _selectedCategory;
  late List<String> _categories;
  String? _categoryError;
  int _contentCharCount = 0;

  final List<Color> _colors = [
    const Color(0xFF6C5CE7),
    const Color(0xFF00D2FF),
    const Color(0xFFFF6B9D),
    const Color(0xFFFFA502),
    const Color(0xFF26DE81),
    const Color(0xFFFC5C65),
    const Color(0xFF45AAF2),
    const Color(0xFFFD79A8),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _newCategoryController = TextEditingController();
    _selectedColor = widget.note?.color ?? _colors[0];
    final baseCategories = widget.categories.isNotEmpty ? widget.categories : ['General'];
    final normalized = baseCategories
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (widget.note?.category != null &&
        widget.note!.category.trim().isNotEmpty &&
        !normalized.any((c) => c.toLowerCase() == widget.note!.category.trim().toLowerCase())) {
      normalized.add(widget.note!.category.trim());
      normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    _categories = normalized.isEmpty ? ['General'] : normalized;
    final existingCategory = widget.note?.category ?? _categories.first;
    final match = _categories.firstWhere(
      (c) => c.toLowerCase() == existingCategory.toLowerCase(),
      orElse: () => _categories.first,
    );
    _selectedCategory = match;
  _contentCharCount = _contentController.text.length;

    _contentController.addListener(_handleContentChanged);
    _newCategoryController.addListener(_clearCategoryErrorOnInput);
  }

  @override
  void dispose() {
    _contentController.removeListener(_handleContentChanged);
    _newCategoryController.removeListener(_clearCategoryErrorOnInput);
    _titleController.dispose();
    _contentController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _handleContentChanged() {
  final length = _contentController.text.length;
    if (length != _contentCharCount) {
      setState(() {
        _contentCharCount = length;
      });
    }
  }

  void _clearCategoryErrorOnInput() {
    if (_categoryError != null && _newCategoryController.text.isNotEmpty) {
      setState(() {
        _categoryError = null;
      });
    }
  }

  void _handleSave() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      content: _contentController.text,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      color: _selectedColor,
      category: _selectedCategory,
    );

    widget.onSave(note);
    Navigator.pop(context);
  }

  void _handleAddCategory() {
    final raw = _newCategoryController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _categoryError = 'Enter a category name';
      });
      return;
    }
    final lower = raw.toLowerCase();
    final exists = _categories.any((c) => c.toLowerCase() == lower);
    if (exists) {
      setState(() {
        _categoryError = 'Category already exists';
      });
      return;
    }
    widget.onCreateCategory(raw);
    setState(() {
      _categories.add(raw);
      _categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _selectedCategory = raw;
      _newCategoryController.clear();
      _categoryError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.note == null ? 'New Note' : 'Edit Note',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey[900]!.withValues(alpha: 0.3)
                        : Colors.grey[100],
                  ),
                  autofocus: widget.note == null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey[900]!.withValues(alpha: 0.3)
                        : Colors.grey[100],
                  ),
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 10,
                  maxLines: null,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_contentCharCount.toString()} characters',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _categories.map((category) {
                    final isSelected = category == _selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                      selectedColor: const Color(0xFF6C5CE7),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF2D3436)),
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor:
                          isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF6C5CE7)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryController,
                        decoration: InputDecoration(
                          labelText: 'Create new category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _categoryError,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleAddCategory(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _handleAddCategory,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Voice Notes Page
class VoiceNotesPage extends StatefulWidget {
  final List<VoiceNote> voiceNotes;
  final Function(VoiceNote) onAddVoiceNote;
  final Function(String) onDeleteVoiceNote;

  const VoiceNotesPage({
    super.key,
    required this.voiceNotes,
    required this.onAddVoiceNote,
    required this.onDeleteVoiceNote,
  });

  @override
  State<VoiceNotesPage> createState() => _VoiceNotesPageState();
}

class _VoiceNotesPageState extends State<VoiceNotesPage> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentPlayingId;
  Duration _recordingDuration = Duration.zero;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      Future.delayed(const Duration(seconds: 1), _updateRecordingDuration);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required'),
          ),
        );
      }
    }
  }

  void _updateRecordingDuration() {
    if (_isRecording) {
      setState(() {
        _recordingDuration = _recordingDuration + const Duration(seconds: 1);
      });
      Future.delayed(const Duration(seconds: 1), _updateRecordingDuration);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();

    if (path != null) {
      setState(() {
        _isRecording = false;
      });

      if (mounted) {
        _showSaveVoiceNoteDialog(path);
      }
    }
  }

  void _showSaveVoiceNoteDialog(String filePath) {
    final titleController = TextEditingController();
    Color selectedColor = const Color(0xFF6C5CE7);

    final List<Color> colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF00D2FF),
      const Color(0xFFFF6B9D),
      const Color(0xFFFFA502),
      const Color(0xFF26DE81),
      const Color(0xFFFC5C65),
      const Color(0xFF45AAF2),
      const Color(0xFFFD79A8),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Save Voice Note',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: colors.map((color) {
                      final isSelected = color == selectedColor;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            File(filePath).delete();
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (titleController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a title'),
                                ),
                              );
                              return;
                            }

                            final voiceNote = VoiceNote(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              title: titleController.text,
                              filePath: filePath,
                              createdAt: DateTime.now(),
                              duration: _recordingDuration,
                              color: selectedColor,
                            );

                            widget.onAddVoiceNote(voiceNote);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _playVoiceNote(VoiceNote note) async {
    if (_currentPlayingId == note.id) {
      await _audioPlayer.stop();
      setState(() => _currentPlayingId = null);
    } else {
      await _audioPlayer.play(DeviceFileSource(note.filePath));
      setState(() => _currentPlayingId = note.id);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _currentPlayingId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF6C5CE7), const Color(0xFF00D2FF)]
                    : [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice Notes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '${widget.voiceNotes.length} ${widget.voiceNotes.length == 1 ? 'recording' : 'recordings'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 24),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _toggleRecording,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isRecording
                                  ? [Colors.red, Colors.red[700]!]
                                  : [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : const Color(0xFF6C5CE7))
                                    .withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isRecording
                            ? _formatDuration(_recordingDuration)
                            : 'Tap to record',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isRecording ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.voiceNotes.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 40),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.mic_none_rounded,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No voice notes yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the microphone to record your first voice note',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...widget.voiceNotes.map((note) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: VoiceNoteCard(
                          note: note,
                          isPlaying: _currentPlayingId == note.id,
                          onPlay: () => _playVoiceNote(note),
                          onDelete: () => _confirmDeleteVoiceNote(note.id),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteVoiceNote(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Voice Note'),
        content: const Text('Are you sure you want to delete this voice note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeleteVoiceNote(id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

// Voice Note Card
class VoiceNoteCard extends StatelessWidget {
  final VoiceNote note;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const VoiceNoteCard({
    super.key,
    required this.note,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: note.color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [note.color, note.color.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(note.duration),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(note.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
