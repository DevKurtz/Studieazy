import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';

/// PostgreSQL persistence through Supabase's Data API with RLS enforced.
class SupabaseQuizService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> saveQuiz(QuizModel quiz, List<QuestionModel> questions) async {
    await _client.from('quizzes').upsert({
      'id': quiz.id,
      'user_id': quiz.userId,
      'title': quiz.title,
      'description': quiz.description,
      'category': quiz.category,
      'study_count': quiz.studyCount ?? 0,
      'average_score': quiz.averageScore ?? 0,
      'created_at': quiz.createdAt.toIso8601String(),
      'last_modified_at': quiz.lastModifiedAt?.toIso8601String(),
    });

    if (questions.isNotEmpty) {
      await _client.from('questions').upsert(
            questions.map(_questionToRow).toList(),
          );
    }
  }

  Future<void> saveQuizOnly(QuizModel quiz) => saveQuiz(quiz, const []);

  Future<void> saveQuestion(QuestionModel question) async {
    await _client.from('questions').upsert(_questionToRow(question));
    await _client.from('quizzes').update({
      'last_modified_at': DateTime.now().toIso8601String(),
    }).eq('id', question.quizId);
  }

  Future<void> updateQuiz({
    required String quizId,
    String? title,
    String? description,
    String? category,
  }) async {
    final updates = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      'last_modified_at': DateTime.now().toIso8601String(),
    };
    await _client.from('quizzes').update(updates).eq('id', quizId);
  }

  Future<void> updateQuestion(QuestionModel question) async {
    final row = _questionToRow(question)..remove('id')..remove('quiz_id')..remove('created_at');
    await _client.from('questions').update(row).eq('id', question.id);
    await _client.from('quizzes').update({
      'last_modified_at': DateTime.now().toIso8601String(),
    }).eq('id', question.quizId);
  }

  Future<QuestionModel?> updateQuestionFields({
    required String questionId,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    bool? isFlashcard,
    String? flashcardBack,
    String? questionType,
    String? imageUrl,
  }) async {
    final rows = await _client.from('questions').select()
        .eq('id', questionId).limit(1);
    if ((rows as List).isEmpty) return null;
    final original = QuestionModel.fromFirestore(
      _questionFromRow(Map<String, dynamic>.from(rows.first as Map)),
    );
    final updated = original.copyWith(
      questionText: questionText,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      isFlashcard: isFlashcard,
      flashcardBack: flashcardBack,
      questionType: questionType,
      imageUrl: imageUrl,
    );
    await updateQuestion(updated);
    return updated;
  }

  Future<void> deleteQuestion(String questionId) async {
    final rows = await _client.from('questions').select('quiz_id')
        .eq('id', questionId).limit(1);
    if ((rows as List).isEmpty) return;
    final quizId = (rows.first as Map)['quiz_id'] as String;
    await _client.from('questions').delete().eq('id', questionId);
    await _client.from('quizzes').update({
      'last_modified_at': DateTime.now().toIso8601String(),
    }).eq('id', quizId);
  }

  Future<void> deleteQuiz(String quizId) async {
    await _client.from('quizzes').delete().eq('id', quizId);
  }

  Future<List<QuizModel>> getUserQuizzes(String userId) async {
    final rows = await _client.from('quizzes').select()
        .eq('user_id', userId).order('created_at', ascending: false).limit(500);
    return (rows as List).map((row) => QuizModel.fromFirestore(
      _quizFromRow(Map<String, dynamic>.from(row as Map)),
    )).toList();
  }

  Stream<List<QuizModel>> watchUserQuizzes(String userId) {
    return _client
        .from('quizzes')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(500)
        .map((rows) => rows
            .map((row) => QuizModel.fromFirestore(_quizFromRow(row)))
            .toList());
  }

  Future<(QuizModel?, List<QuestionModel>)> getQuizWithQuestions(
    String quizId,
    String userId,
  ) async {
    final rows = await _client.from('quizzes').select()
        .eq('id', quizId).eq('user_id', userId).limit(1);
    if ((rows as List).isEmpty) return (null, <QuestionModel>[]);
    final quiz = QuizModel.fromFirestore(
      _quizFromRow(Map<String, dynamic>.from(rows.first as Map)),
    );
    final questionRows = await _client.from('questions').select()
        .eq('quiz_id', quizId).order('created_at');
    final questions = (questionRows as List).map((row) =>
      QuestionModel.fromFirestore(_questionFromRow(Map<String, dynamic>.from(row as Map)))
    ).toList();
    return (quiz.copyWith(questionIds: questions.map((q) => q.id).toList()), questions);
  }

  Future<QuizModel?> updateQuizStats(
    String quizId,
    int score,
    int totalQuestions,
    String userId,
  ) async {
    final rows = await _client.from('quizzes').select()
        .eq('id', quizId).eq('user_id', userId).limit(1);
    if ((rows as List).isEmpty) return null;
    final quiz = QuizModel.fromFirestore(
      _quizFromRow(Map<String, dynamic>.from(rows.first as Map)),
    );
    final count = (quiz.studyCount ?? 0) + 1;
    final ratio = totalQuestions > 0 ? score / totalQuestions : 0.0;
    final average = ((quiz.averageScore ?? 0) * (count - 1) + ratio) / count;
    await _client.from('quizzes').update({
      'study_count': count,
      'average_score': average,
      'last_modified_at': DateTime.now().toIso8601String(),
    }).eq('id', quizId).eq('user_id', userId);
    return quiz.copyWith(studyCount: count, averageScore: average);
  }

  Map<String, dynamic> _questionToRow(QuestionModel q) => {
        'id': q.id,
        'quiz_id': q.quizId,
        'question_text': q.questionText,
        'options': q.options,
        'correct_answer_index': q.correctAnswerIndex,
        'is_flashcard': q.isFlashcard,
        'flashcard_back': q.flashcardBack,
        'question_type': q.questionType,
        'image_url': q.imageUrl,
        'created_at': q.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _questionFromRow(Map<String, dynamic> r) => {
        'id': r['id'], 'quizId': r['quiz_id'],
        'questionText': r['question_text'], 'options': r['options'],
        'correctAnswerIndex': r['correct_answer_index'],
        'isFlashcard': r['is_flashcard'], 'flashcardBack': r['flashcard_back'],
        'questionType': r['question_type'], 'imageUrl': r['image_url'],
        'createdAt': r['created_at'],
      };

  Map<String, dynamic> _quizFromRow(Map<String, dynamic> r) => {
        'id': r['id'], 'userId': r['user_id'], 'title': r['title'],
        'description': r['description'], 'category': r['category'],
        'questionIds': <String>[], 'studyCount': r['study_count'],
        'averageScore': r['average_score'], 'createdAt': r['created_at'],
        'lastModifiedAt': r['last_modified_at'],
      };
}
