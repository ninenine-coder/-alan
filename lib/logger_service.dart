import 'package:logging/logging.dart';

class LoggerService {
  static final Logger _logger = Logger('AppLogger');
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    
    // 設置日誌級別
    Logger.root.level = Level.ALL;
    
    // 設置日誌輸出格式
    Logger.root.onRecord.listen((record) {
      final timestamp = record.time.toIso8601String();
      final level = record.level.name;
      final loggerName = record.loggerName;
      final message = record.message;
      
      // 在開發模式下使用彩色輸出
      if (record.level >= Level.SEVERE) {
        print('🔴 [$timestamp] $level [$loggerName] $message');
      } else if (record.level >= Level.WARNING) {
        print('🟡 [$timestamp] $level [$loggerName] $message');
      } else if (record.level >= Level.INFO) {
        print('🔵 [$timestamp] $level [$loggerName] $message');
      } else {
        print('⚪ [$timestamp] $level [$loggerName] $message');
      }
    });
    
    _isInitialized = true;
  }

  static void debug(String message) {
    _logger.fine(message);
  }

  static void info(String message) {
    _logger.info(message);
  }

  static void warning(String message) {
    _logger.warning(message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  static void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }
}
