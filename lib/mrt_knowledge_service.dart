import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

class MRTKnowledgeService {
  static const String _questionsCollection = 'taipei_metro_quiz';
  static const String _leaderboardCollection = 'mrt_leaderboard';
  static const String _userProgressCollection = 'mrt_user_progress';
  
  // 遊戲設定
  static const int totalQuestionsPerGame = 5;
  static const int timeLimitPerQuestion = 10;
  static const int fastAnswerBonusThreshold = 5;
  
  // 計分系統
  static const Map<String, int> difficultyPoints = {
    'easy': 10,
    'medium': 20,
    'hard': 30,
  };
  
  static const int comboBonusPerLevel = 5;
  static const double timeBonusMultiplier = 0.5;
  
  // 本地遊戲狀態
  static List<String> _usedQuestionIds = [];
  static List<Map<String, dynamic>> _currentQuestions = [];
  static int _currentQuestionIndex = 0;
  static int _currentScore = 0;
  static int _currentCombo = 0;
  static DateTime? _gameStartTime;
  static String _currentMode = 'normal';
  
  /// 開始新遊戲
  static Future<Map<String, dynamic>> startGame({String mode = 'normal'}) async {
    try {
      _currentMode = mode;
      _usedQuestionIds.clear();
      _currentQuestions.clear();
      _currentQuestionIndex = 0;
      _currentScore = 0;
      _currentCombo = 0;
      _gameStartTime = DateTime.now();
      
      // 從 Firebase 獲取所有題目
      final querySnapshot = await FirebaseFirestore.instance
          .collection(_questionsCollection)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        throw Exception('沒有找到題目');
      }
      
      // 隨機選擇題目，確保不重複
      final allQuestions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'text': data['question'] ?? data['text'] ?? '',
          'options': _prepareOptions(data),
          'correct_answer': data['correct_answer'] ?? '',
          'difficulty': data['difficulty'] ?? 'medium',
          'explanation': data['explanation'] ?? '',
        };
      }).toList();
      
      // 隨機打亂題目順序
      allQuestions.shuffle();
      
      // 選擇指定數量的題目
      final questionsToUse = allQuestions.take(totalQuestionsPerGame).toList();
      _currentQuestions = questionsToUse;
      
      // 保存已使用的題目ID，防止重複
      _usedQuestionIds.addAll(questionsToUse.map((q) => q['id']));
      
      LoggerService.info('遊戲開始 - 模式: $mode, 題目數量: ${questionsToUse.length}');
      
      return {
        'question': questionsToUse.first,
        'total_questions': questionsToUse.length,
        'mode': mode,
      };
    } catch (e) {
      LoggerService.error('開始遊戲失敗: $e');
      rethrow;
    }
  }
  
  /// 準備選項
  static List<String> _prepareOptions(Map<String, dynamic> data) {
    final correctAnswer = data['correct_answer'] ?? '';
    final wrongAnswers = List<String>.from(data['wrong_answers'] ?? []);
    
    // 確保有足夠的錯誤選項
    while (wrongAnswers.length < 3) {
      wrongAnswers.add('選項 ${wrongAnswers.length + 1}');
    }
    
    // 隨機選擇3個錯誤選項
    wrongAnswers.shuffle();
    final selectedWrongAnswers = wrongAnswers.take(3).toList();
    
    // 組合所有選項並隨機排序
    final allOptions = <String>[correctAnswer, ...selectedWrongAnswers];
    allOptions.shuffle();
    
    return allOptions;
  }
  
  /// 提交答案
  static Future<Map<String, dynamic>> submitAnswer(String answer) async {
    try {
      if (_currentQuestions.isEmpty || _currentQuestionIndex >= _currentQuestions.length) {
        throw Exception('沒有更多題目');
      }
      
      final currentQuestion = _currentQuestions[_currentQuestionIndex];
      final correctAnswer = currentQuestion['correct_answer'];
      final isCorrect = answer == correctAnswer;
      
      // 計算分數
      int pointsEarned = 0;
      String feedback = '';
      
      if (isCorrect) {
        // 基礎分數
        final difficulty = currentQuestion['difficulty'] ?? 'medium';
        pointsEarned = difficultyPoints[difficulty] ?? 10;
        
        // 連擊獎勵
        _currentCombo++;
        if (_currentCombo > 1) {
          pointsEarned += comboBonusPerLevel * (_currentCombo - 1);
        }
        
        // 時間獎勵（如果快速答題）
        if (_gameStartTime != null) {
          final timeElapsed = DateTime.now().difference(_gameStartTime!).inSeconds;
          if (timeElapsed <= fastAnswerBonusThreshold) {
            final timeBonus = (pointsEarned * timeBonusMultiplier).round();
            pointsEarned += timeBonus;
          }
        }
        
        _currentScore += pointsEarned;
        feedback = '正確！+$pointsEarned 分';
      } else {
        // 答錯重置連擊
        _currentCombo = 0;
        feedback = '錯誤！正確答案是：$correctAnswer';
      }
      
      _currentQuestionIndex++;
      
      // 檢查遊戲是否結束
      if (_currentQuestionIndex >= _currentQuestions.length) {
        // 遊戲結束，保存分數
        await _saveScoreToLeaderboard(_currentScore);
        await _saveUserProgress(_currentScore, _currentQuestions.length);
        
        return {
          'game_over': true,
          'score': _currentScore,
          'total_questions': _currentQuestions.length,
          'correct_answers': _currentQuestions.where((q) => q['correct_answer'] == answer).length,
          'correct_answer': correctAnswer,
          'feedback': feedback,
          'points_earned': pointsEarned,
          'is_correct': isCorrect,
        };
      } else {
        // 還有下一題
        final nextQuestion = _currentQuestions[_currentQuestionIndex];
        
        return {
          'game_over': false,
          'score': _currentScore,
          'combo': _currentCombo,
          'next_question': nextQuestion,
          'correct_answer': correctAnswer,
          'feedback': feedback,
          'points_earned': pointsEarned,
          'is_correct': isCorrect,
        };
      }
    } catch (e) {
      LoggerService.error('提交答案失敗: $e');
      rethrow;
    }
  }
  
  /// 獲取錯誤答案列表
  static List<Map<String, dynamic>> getWrongAnswers() {
    // 這裡可以實現獲取錯誤答案的邏輯
    return [];
  }
  
  /// 獲取排行榜
  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(_leaderboardCollection)
          .orderBy('score', descending: true)
          .limit(10)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'rank': 0, // 可以在這裡計算排名
          'score': data['score'] ?? 0,
          'player_name': data['player_name'] ?? '匿名玩家',
          'date': data['date']?.toDate(),
        };
      }).toList();
    } catch (e) {
      LoggerService.error('獲取排行榜失敗: $e');
      return [];
    }
  }
  
  /// 獲取用戶進度
  static Future<Map<String, dynamic>> getUserProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'highest_score': 0,
          'total_games': 0,
          'total_questions_answered': 0,
        };
      }
      
      final doc = await FirebaseFirestore.instance
          .collection(_userProgressCollection)
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        return {
          'highest_score': 0,
          'total_games': 0,
          'total_questions_answered': 0,
        };
      }
      
      final data = doc.data()!;
      return {
        'highest_score': data['highest_score'] ?? 0,
        'total_games': data['total_games'] ?? 0,
        'total_questions_answered': data['total_questions_answered'] ?? 0,
      };
    } catch (e) {
      LoggerService.error('獲取用戶進度失敗: $e');
      return {
        'highest_score': 0,
        'total_games': 0,
        'total_questions_answered': 0,
      };
    }
  }
  
  /// 保存分數到排行榜
  static Future<void> _saveScoreToLeaderboard(int score) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection(_leaderboardCollection)
          .add({
        'user_id': user.uid,
        'player_name': user.displayName ?? '匿名玩家',
        'score': score,
        'date': FieldValue.serverTimestamp(),
        'mode': _currentMode,
      });
      
      LoggerService.info('分數已保存到排行榜: $score');
    } catch (e) {
      LoggerService.error('保存分數到排行榜失敗: $e');
    }
  }
  
  /// 保存用戶進度
  static Future<void> _saveUserProgress(int score, int totalQuestions) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final userRef = FirebaseFirestore.instance
          .collection(_userProgressCollection)
          .doc(user.uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(userRef);
        
        if (!doc.exists) {
          transaction.set(userRef, {
            'highest_score': score,
            'total_games': 1,
            'total_questions_answered': totalQuestions,
            'last_updated': FieldValue.serverTimestamp(),
          });
        } else {
          final data = doc.data()!;
          final currentHighest = data['highest_score'] ?? 0;
          final currentGames = data['total_games'] ?? 0;
          final currentQuestions = data['total_questions_answered'] ?? 0;
          
          transaction.update(userRef, {
            'highest_score': score > currentHighest ? score : currentHighest,
            'total_games': currentGames + 1,
            'total_questions_answered': currentQuestions + totalQuestions,
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      });
      
      LoggerService.info('用戶進度已更新');
    } catch (e) {
      LoggerService.error('保存用戶進度失敗: $e');
    }
  }
  
  /// 重置遊戲
  static void resetGame() {
    _usedQuestionIds.clear();
    _currentQuestions.clear();
    _currentQuestionIndex = 0;
    _currentScore = 0;
    _currentCombo = 0;
    _gameStartTime = null;
  }
}
