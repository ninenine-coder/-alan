import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'mrt_knowledge_service.dart';
import 'logger_service.dart';

class MRTKnowledgePage extends StatefulWidget {
  const MRTKnowledgePage({super.key});

  @override
  State<MRTKnowledgePage> createState() => _MRTKnowledgePageState();
}

class _MRTKnowledgePageState extends State<MRTKnowledgePage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _gameStarted = false;
  bool _gameOver = false;
  String _currentMode = 'normal';
  
  // 遊戲狀態
  Map<String, dynamic>? _currentQuestion;
  int _currentScore = 0;
  int _currentCombo = 0;
  int _totalQuestions = 0;
  int _currentQuestionIndex = 0;
  int _timeRemaining = 10;
  bool _isAnswering = false;
  
  // 答題狀態
  String? _selectedAnswer;
  String? _correctAnswer;
  bool _showAnswerFeedback = false;
  
  // 動畫控制器
  late AnimationController _timerController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  
  // 計時器
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    
    _timerController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _timerController.dispose();
    _scoreController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 開始新遊戲
  Future<void> _startGame() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await MRTKnowledgeService.startGame(mode: _currentMode);
      
      // 延遲2秒後顯示題目
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _gameStarted = true;
          _gameOver = false;
          _currentQuestion = result['question'];
          _totalQuestions = result['total_questions'];
          _currentQuestionIndex = 1;
          _currentScore = 0;
          _currentCombo = 0;
          _timeRemaining = 10;
          _isAnswering = false;
          _selectedAnswer = null;
          _correctAnswer = null;
          _showAnswerFeedback = false;
        });
        
        _startTimer();
        LoggerService.info('遊戲開始成功');
      }
    } catch (e) {
      LoggerService.error('開始遊戲失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('開始遊戲失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 開始計時器
  void _startTimer() {
    _timerController.reset();
    _timerController.forward();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _timeRemaining--;
      });
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _submitAnswer(''); // 時間到，自動提交空答案
      }
    });
  }

  /// 提交答案
  Future<void> _submitAnswer(String answer) async {
    if (_isAnswering) return;
    
    setState(() {
      _isAnswering = true;
      _selectedAnswer = answer;
    });
    
    _timer?.cancel();
    
    try {
      final result = await MRTKnowledgeService.submitAnswer(answer);
      
      if (result['game_over'] == true) {
        // 遊戲結束
        setState(() {
          _gameOver = true;
          _currentScore = result['score'];
          _showAnswerFeedback = true;
          _correctAnswer = result['correct_answer'];
        });
        
        // 延遲2秒後顯示遊戲結束對話框
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _showGameOverDialog();
          }
        });
      } else {
        // 顯示答案反饋
        setState(() {
          _showAnswerFeedback = true;
          _correctAnswer = result['correct_answer'];
        });
        
        // 延遲2秒後進入下一題
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentQuestion = result['next_question'];
              _currentScore = result['score'];
              _currentCombo = result['combo'];
              _currentQuestionIndex++;
              _timeRemaining = 10;
              _isAnswering = false;
              _selectedAnswer = null;
              _correctAnswer = null;
              _showAnswerFeedback = false;
            });
            
            // 開始下一題計時器
            _startTimer();
          }
        });
      }
    } catch (e) {
      LoggerService.error('提交答案失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交答案失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 顯示答題反饋
  void _displayAnswerFeedback(Map<String, dynamic> result) {
    final isCorrect = result['is_correct'] as bool;
    final feedback = result['feedback'] as String;
    final pointsEarned = result['points_earned'] as int;
    
    if (isCorrect && pointsEarned > 0) {
      _scoreController.forward().then((_) {
        _scoreController.reverse();
      });
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(feedback)),
          ],
        ),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 顯示遊戲結束對話框
  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('遊戲結束'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '最終分數: $_currentScore',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text('總題數: $_totalQuestions'),
            const SizedBox(height: 8),
            Text('正確題數: ${_currentScore ~/ 10}'), // 假設每題10分
            const SizedBox(height: 8),
            Text('正確率: ${((_currentScore ~/ 10) / _totalQuestions * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('再玩一次'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('返回主頁'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 重置遊戲
  void _resetGame() {
    setState(() {
      _gameStarted = false;
      _gameOver = false;
      _currentQuestion = null;
      _currentScore = 0;
      _currentCombo = 0;
      _totalQuestions = 0;
      _currentQuestionIndex = 0;
      _timeRemaining = 10;
      _isAnswering = false;
      _selectedAnswer = null;
      _correctAnswer = null;
      _showAnswerFeedback = false;
    });
    
    _timerController.reset();
    _scoreController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MRT 知識問答'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gameStarted
              ? _buildGameUI()
              : _buildStartScreen(),
    );
  }

  /// 構建開始畫面
  Widget _buildStartScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue[100]!,
            Colors.blue[50]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subway,
              size: 100,
              color: Colors.blue[600],
            ),
            const SizedBox(height: 32),
            const Text(
              'MRT 知識問答',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '測試你對台北捷運的了解程度！',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 48),
            
            // 模式選擇
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      '選擇遊戲模式',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('一般模式'),
                            subtitle: const Text('5題'),
                            value: 'normal',
                            groupValue: _currentMode,
                            onChanged: (value) {
                              setState(() {
                                _currentMode = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('限時挑戰'),
                            subtitle: const Text('5題'),
                            value: 'time_attack',
                            groupValue: _currentMode,
                            onChanged: (value) {
                              setState(() {
                                _currentMode = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '開始遊戲',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 構建遊戲畫面
  Widget _buildGameUI() {
    if (_currentQuestion == null) {
      return const Center(child: Text('載入題目中...'));
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue[100]!,
            Colors.blue[50]!,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 頂部狀態欄
            _buildStatusBar(),
            
            // 題目內容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 題目文字
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  '第 $_currentQuestionIndex 題',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$_currentQuestionIndex / $_totalQuestions',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentQuestion!['text'],
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 選項
                    Expanded(
                      child: ListView.builder(
                        itemCount: (_currentQuestion!['options'] as List).length,
                        itemBuilder: (context, index) {
                          final option = _currentQuestion!['options'][index];
                          final isSelected = _selectedAnswer == option;
                          final isCorrect = _showAnswerFeedback && option == _correctAnswer;
                          final isWrong = _showAnswerFeedback && option == _selectedAnswer && option != _correctAnswer;
                          final isCorrectButNotSelected = _showAnswerFeedback && option == _correctAnswer && !isSelected;
                          
                          // 決定背景顏色
                          Color backgroundColor;
                          if (_showAnswerFeedback) {
                            if (isCorrect) {
                              backgroundColor = Colors.green[100]!;
                            } else if (isWrong) {
                              backgroundColor = Colors.red[100]!;
                            } else if (isCorrectButNotSelected) {
                              backgroundColor = Colors.green[50]!;
                            } else {
                              backgroundColor = Colors.grey[100]!;
                            }
                          } else {
                            backgroundColor = Colors.white;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: backgroundColor,
                            child: InkWell(
                              onTap: _isAnswering ? null : () => _submitAnswer(option),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? (isCorrect ? Colors.green : Colors.red)
                                            : (isCorrectButNotSelected ? Colors.green[200] : Colors.blue[100]),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          String.fromCharCode(65 + index), // A, B, C, D
                                          style: TextStyle(
                                            color: isSelected 
                                                ? Colors.white
                                                : (isCorrectButNotSelected ? Colors.green[800] : Colors.blue[600]),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isSelected 
                                              ? (isCorrect ? Colors.green[800] : Colors.red[800])
                                              : (isCorrectButNotSelected ? Colors.green[800] : Colors.black87),
                                          fontWeight: isSelected || isCorrectButNotSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    // 顯示正確/錯誤圖標
                                    if (_showAnswerFeedback)
                                      Icon(
                                        isCorrect ? Icons.check_circle : (isWrong ? Icons.cancel : null),
                                        color: isCorrect ? Colors.green : (isWrong ? Colors.red : null),
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 構建狀態欄
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 分數
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_scoreAnimation.value * 0.2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '分數: $_currentScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(width: 16),
          
          // 連擊
          if (_currentCombo > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '🔥 連擊 x$_currentCombo',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          const Spacer(),
          
          // 計時器
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, child) {
              final progress = _timerController.value;
              final color = progress > 0.3 ? Colors.green : Colors.red;
              
              return Container(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeWidth: 6,
                    ),
                    Center(
                      child: Text(
                        '$_timeRemaining',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
