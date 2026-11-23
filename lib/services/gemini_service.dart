import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/quiz_model.dart';
import '../models/question_model.dart';

/// Result returned by [GeminiService.generateQuiz].
class GeneratedQuizResult {
  final String title;
  final String? description;
  final String? category;
  final List<GeneratedQuestion> questions;

  GeneratedQuizResult({
    required this.title,
    this.description,
    this.category,
    required this.questions,
  });
}

class GeneratedQuestion {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final bool isFlashcard;
  final String? flashcardBack;
  final String
  questionType; // 'mcq', 'flashcard', 'identification', 'enumeration'

  GeneratedQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.isFlashcard,
    this.flashcardBack,
    this.questionType = 'mcq',
  });
}

class GeminiService {
  static const _functionName = 'generate-quiz';

  Future<GeneratedQuizResult> _generateWithBackend({
    required List<Map<String, dynamic>> parts,
    required String prompt,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception(
        'AI quiz generation needs the Supabase connection. Run the app with '
        'the Supabase publishable key after the generate-quiz function is deployed.',
      );
    }

    final response = await Supabase.instance.client.functions.invoke(
      _functionName,
      body: {
        'parts': [
          ...parts,
          {'text': prompt},
        ],
      },
    );
    final data = response.data;
    if (data is! Map || data['result'] is! Map) {
      throw const FormatException(
        'The AI service returned an invalid response.',
      );
    }
    return _parseResponse(jsonEncode(data['result']));
  }

  /// Generate a quiz from multiple files simultaneously.
  Future<GeneratedQuizResult> generateQuizFromMultipleFiles({
    required List<({Uint8List bytes, String fileName})> files,
    int questionCount = 10,
    String difficulty = 'Medium',
    List<String>? selectedTypes,
    String? customInstruction,
  }) async {
    if (files.isEmpty) {
      throw Exception('No files selected.');
    }
    if (files.length == 1) {
      return generateQuiz(
        fileBytes: files.first.bytes,
        fileName: files.first.fileName,
        questionCount: questionCount,
        difficulty: difficulty,
        selectedTypes: selectedTypes,
        customInstruction: customInstruction,
      );
    }

    final prompt = _buildPrompt(
      questionCount,
      difficulty,
      selectedTypes,
      customInstruction,
    );
    final List<Map<String, dynamic>> parts = [];

    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final ext = f.fileName.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        parts.add({
          'inlineData': {
            'mimeType': 'application/pdf',
            'data': base64Encode(f.bytes),
          },
        });
      } else {
        final text = await extractText(f.bytes, ext);
        if (text != null && text.trim().isNotEmpty) {
          parts.add({'text': 'DOCUMENT ${i + 1} (${f.fileName}):\n$text'});
        }
      }
    }
    return _generateWithBackend(parts: parts, prompt: prompt);
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Extract readable text from file bytes depending on [extension].
  /// Returns null if extraction fails or format is unsupported.
  Future<String?> extractText(Uint8List bytes, String extension) async {
    String? extracted;
    switch (extension.toLowerCase()) {
      case 'txt':
        extracted = utf8.decode(bytes, allowMalformed: true);
        break;
      case 'docx':
        extracted = _extractDocxText(bytes);
        break;
      case 'pptx':
        extracted = _extractPptxText(bytes);
        break;
      case 'pdf':
        // PDF extraction needs an additional library that is not available in
        // this offline workspace. Keep PDFs supported by quiz generation only.
        return null;
      case 'ppt':
        // Legacy binary PowerPoint is not a ZIP/XML format. Gemini can read it
        // for quiz generation, but it cannot be safely converted to text here.
        return null;
      default:
        return null;
    }
    return cleanExtractedDocumentText(extracted);
  }


  /// Generate a quiz from [fileBytes].
  /// [fileName] is used to determine MIME type.
  /// [questionCount] controls how many questions to ask for (up to 50).
  /// [difficulty] controls question complexity ('Easy', 'Medium', 'High', 'Extreme').
  /// [customInstruction] custom prompt / chatbox instructions from user.
  Future<GeneratedQuizResult> generateQuiz({
    required Uint8List fileBytes,
    required String fileName,
    int questionCount = 10,
    String difficulty = 'Medium',
    List<String>? selectedTypes,
    String? customInstruction,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final prompt = _buildPrompt(
      questionCount,
      difficulty,
      selectedTypes,
      customInstruction,
    );

    List<Map<String, dynamic>> parts;

    if (ext == 'pdf') {
      parts = [
        {
          'inlineData': {
            'mimeType': 'application/pdf',
            'data': base64Encode(fileBytes),
          },
        },
      ];
    } else {
      final text = await extractText(fileBytes, ext);
      if (text == null || text.trim().isEmpty) {
        throw Exception(
          'Could not extract text from the file. '
          'Try saving it as a PDF or plain text.',
        );
      }
      parts = [
        {'text': 'DOCUMENT CONTENT:\n$text'},
      ];
    }
    return _generateWithBackend(parts: parts, prompt: prompt);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  String _buildPrompt(
    int count,
    String difficulty,
    List<String>? selectedTypes,
    String? customInstruction,
  ) {
    String difficultyRules;

    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyRules = '''
DIFFICULTY LEVEL: EASY
- Generate simple, direct factual questions directly based on key facts in the document.
- Example: "What country has high corruption?" -> Answer: "Philippines"
''';
        break;
      case 'high':
      case 'hard':
        difficultyRules = '''
DIFFICULTY LEVEL: HIGH
- Generate scenario and example-based questions, but DO NOT provide obvious explanations or hints in the question itself.
- Example: "John sends a suspicious link to Mike." -> Question asks what type of hacking John did (Phishing).
''';
        break;
      case 'extreme':
        difficultyRules = '''
DIFFICULTY LEVEL: EXTREME
- Generate fill-in-the-blank style questions using "_____" in the question text.
- Example: "DDOS can _____ your database." -> Answer: "Spam"
''';
        break;
      case 'medium':
      default:
        difficultyRules = '''
DIFFICULTY LEVEL: MEDIUM
- Generate scenario and example-based questions with clear context.
- Example: "John sends a suspicious link to Mike. What type of hacking did John do?" -> Answer: "Phishing"
''';
        break;
    }

    String instructionSection = '';
    if (customInstruction != null && customInstruction.trim().isNotEmpty) {
      instructionSection = '''
USER CHATBOX INSTRUCTIONS:
"${customInstruction.trim()}"
Follow the above instructions carefully when generating questions.
''';
    }

    // Build allowed types section — flashcard is never a standalone type.
    final allowedTypes =
        (selectedTypes != null && selectedTypes.isNotEmpty)
            ? selectedTypes.where((t) => t != 'flashcard').toList()
            : ['mcq', 'identification', 'enumeration'];
    final typeDescriptions = {
      'mcq': '"mcq": Multiple choice (4 choices, 1 correct index)',
      'identification': '"identification": Short keyword answer (user types)',
      'enumeration': '"enumeration": List of key terms (comma-separated)',
    };
    final allowedTypeBlock = allowedTypes
        .map((t) => '   - ${typeDescriptions[t] ?? t}')
        .join('\n');

    return '''
You are an expert educational quiz generator.
Analyse the provided document and generate questions based on it.

STRICT MANDATORY RULES:
1. QUANTITY RULE: You MUST generate EXACTLY $count questions in total. Do NOT generate less than $count or more than $count. The array "questions" MUST contain exactly $count items.
2. QUESTION TYPES TO INCLUDE — use ONLY these types:
$allowedTypeBlock

IMPORTANT ANSWER FORMAT RULE FOR IDENTIFICATION & ENUMERATION:
Answers for "identification" and "enumeration" MUST be short keywords, names, or key phrases (1 to 4 words max). NEVER require a full sentence answer.

$difficultyRules

$instructionSection

Return ONLY valid JSON matching this exact schema — no markdown, no conversational explanation outside JSON:

{
  "quiz_title": "<concise title>",
  "quiz_description": "<one-sentence description>",
  "quiz_category": "<subject area>",
  "questions": [
    {
      "type": "mcq",
      "question": "...",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_answer_index": 0
    },
    {
      "type": "identification",
      "question": "...",
      "answer": "<short keyword/term>"
    },
    {
      "type": "enumeration",
      "question": "...",
      "items": ["Item 1", "Item 2"]
    }
  ]
}''';
  }

  GeneratedQuizResult _parseResponse(String raw) {
    // Strip any accidental markdown fences.
    final cleaned =
        raw
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();

    final Map<String, dynamic> json =
        jsonDecode(cleaned) as Map<String, dynamic>;

    final rawQuestions = (json['questions'] as List<dynamic>);
    final questions =
        rawQuestions.map((q) {
          final map = q as Map<String, dynamic>;
          final type = (map['type'] as String?)?.toLowerCase() ?? 'mcq';

          // flashcard type is no longer standalone — treat as identification.
          if (type == 'flashcard' || type == 'identification') {
            final ans = (map['answer'] as String?) ?? '';
            return GeneratedQuestion(
              questionText: (map['question'] as String?) ?? '',
              options: [ans],
              correctAnswerIndex: 0,
              isFlashcard: false,
              flashcardBack: ans,
              questionType: 'identification',
            );
          } else if (type == 'enumeration') {
            final rawItems = map['items'] as List<dynamic>?;
            final items =
                rawItems != null
                    ? rawItems.map((e) => e.toString()).toList()
                    : [(map['answer'] as String?) ?? ''];
            return GeneratedQuestion(
              questionText: (map['question'] as String?) ?? '',
              options: items,
              correctAnswerIndex: 0,
              isFlashcard: false,
              flashcardBack: items.join(', '),
              questionType: 'enumeration',
            );
          } else {
            // mcq — set flashcardBack to the correct option text automatically.
            final opts =
                (map['options'] as List<dynamic>?)
                    ?.map((o) => o.toString())
                    .toList() ??
                ['Option A', 'Option B', 'Option C', 'Option D'];
            final correctIdx = (map['correct_answer_index'] as int?) ?? 0;
            final safeIdx =
                (correctIdx >= 0 && correctIdx < opts.length) ? correctIdx : 0;
            return GeneratedQuestion(
              questionText: (map['question'] as String?) ?? '',
              options: opts,
              correctAnswerIndex: safeIdx,
              isFlashcard: false,
              flashcardBack: opts.isNotEmpty ? opts[safeIdx] : null,
              questionType: 'mcq',
            );
          }
        }).toList();

    return GeneratedQuizResult(
      title: json['quiz_title'] as String? ?? 'AI Generated Quiz',
      description: json['quiz_description'] as String?,
      category: json['quiz_category'] as String?,
      questions: questions,
    );
  }

  /// Extract plain text from a DOCX file (which is a ZIP of XML files).
  static String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final wordDoc = archive.findFile('word/document.xml');
      if (wordDoc == null) return '';
      final xml = utf8.decode(wordDoc.content as List<int>);
      final paragraphs = RegExp(
        r'<w:p\b[^>]*>(.*?)</w:p>',
        dotAll: true,
      ).allMatches(xml);
      final text = paragraphs
          .map((paragraph) {
            final content = paragraph.group(1) ?? '';
            final runs =
                RegExp(
                  r'<w:t\b[^>]*>(.*?)</w:t>',
                  dotAll: true,
                ).allMatches(content).map((run) => run.group(1) ?? '').join();
            return cleanExtractedDocumentText(runs);
          })
          .where((paragraph) => paragraph.isNotEmpty)
          .join('\n\n');
      return cleanExtractedDocumentText(text);
    } catch (_) {
      return '';
    }
  }

  /// Extract plain text from a PPTX file (also a ZIP of XML files).
  /// Each slide lives under ppt/slides/slideN.xml, with visible text
  /// wrapped in `<a:t>` tags. Slides are read in order and separated so
  /// the AI can still tell where one slide ends and the next begins.
  static String _extractPptxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final slideFiles =
          archive.files
              .where(
                (f) =>
                    f.isFile &&
                    RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name),
              )
              .toList();

      // Sort numerically (slide2 before slide10, etc.) instead of
      // alphabetically.
      slideFiles.sort((a, b) {
        final na = int.parse(RegExp(r'\d+').firstMatch(a.name)!.group(0)!);
        final nb = int.parse(RegExp(r'\d+').firstMatch(b.name)!.group(0)!);
        return na.compareTo(nb);
      });

      final buffer = StringBuffer();
      for (var i = 0; i < slideFiles.length; i++) {
        final xml = utf8.decode(slideFiles[i].content as List<int>);
        final paragraphs = RegExp(
          r'<a:p\b[^>]*>(.*?)</a:p>',
          dotAll: true,
        ).allMatches(xml);
        final paragraphTexts =
            paragraphs
                .map((paragraph) {
                  final content = paragraph.group(1) ?? '';
                  final runs =
                      RegExp(r'<a:t\b[^>]*>(.*?)</a:t>', dotAll: true)
                          .allMatches(content)
                          .map((run) => run.group(1) ?? '')
                          .join();
                  return cleanExtractedDocumentText(runs);
                })
                .where((paragraph) => paragraph.isNotEmpty)
                .toList();
        final slideText = paragraphTexts.join('\n\n');
        if (slideText.trim().isNotEmpty) {
          buffer.writeln('Slide ${i + 1}:');
          buffer.writeln(slideText);
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Word/PPT XML may contain markup that was itself escaped as text.
  /// Decode entities and strip leaked HTML/XML tags before saving or showing.
  static String cleanExtractedDocumentText(String value) {
    var decoded = _decodeDocumentEntities(value);
    decoded = _decodeDocumentEntities(decoded);
    final withParagraphBreaks = decoded
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</?(?:[a-z][\w.-]*:)?(?:p|div|li|h[1-6])\b[^>]*>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(RegExp(r'</?[a-z][^>]*>', caseSensitive: false), ' ')
        .replaceAll('\r', '\n');
    return withParagraphBreaks
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[\t ]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n');
  }

  static String _decodeDocumentEntities(String value) {
    var decoded = value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#(?:x([0-9a-fA-F]+)|(\d+));'),
      (match) {
        final hex = match.group(1);
        final codePoint = int.tryParse(
          hex ?? match.group(2)!,
          radix: hex == null ? 10 : 16,
        );
        return codePoint == null ? ' ' : String.fromCharCode(codePoint);
      },
    );
    return decoded;
  }

  /// Convert a [GeneratedQuizResult] into domain models ready to save.
  static (QuizModel, List<QuestionModel>) toModels(
    GeneratedQuizResult result,
    String userId,
    String quizId,
  ) {
    final now = DateTime.now();
    final questions =
        result.questions.asMap().entries.map((e) {
          final GeneratedQuestion q = e.value;
          final qId = '${quizId}_q${e.key}';
          return QuestionModel(
            id: qId,
            quizId: quizId,
            questionText: q.questionText,
            options: q.options,
            correctAnswerIndex: q.correctAnswerIndex,
            isFlashcard: q.isFlashcard,
            flashcardBack: q.flashcardBack,
            questionType: q.questionType,
            createdAt: now,
          );
        }).toList();

    final quiz = QuizModel(
      id: quizId,
      userId: userId,
      title: result.title,
      description: result.description,
      category: result.category,
      questionIds: questions.map((q) => q.id).toList(),
      createdAt: now,
    );

    return (quiz, questions);
  }
}
