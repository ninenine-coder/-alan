// 這個檔只負責「依平台」去 export 對應的實作
export 'metro_quiz_page_mobile.dart'
  if (dart.library.html) 'metro_quiz_page_web.dart';