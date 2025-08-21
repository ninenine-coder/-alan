import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'animations.dart';

/// 自定義UI組件
class UIComponents {
  /// 美觀的卡片組件
  static Widget beautifulCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    double? elevation,
    BorderRadius? borderRadius,
    bool enableAnimation = true,
  }) {
    final card = Container(
      margin: margin ?? const EdgeInsets.all(8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    return enableAnimation
        ? AppAnimations.fadeIn(child: card)
        : card;
  }

  /// 漸變按鈕組件
  static Widget gradientButton({
    required String text,
    required VoidCallback onPressed,
    List<Color>? gradientColors,
    double? width,
    double? height,
    bool enableAnimation = true,
  }) {
    final button = Container(
      width: width,
      height: height ?? 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors ?? AppTheme.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (gradientColors?.first ?? AppTheme.primaryColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    return enableAnimation
        ? AppAnimations.scaleIn(child: button)
        : button;
  }

  /// 圖標按鈕組件
  static Widget iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
    double? size,
    bool enableAnimation = true,
  }) {
    final button = Container(
      width: size ?? 48,
      height: size ?? 48,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AppTheme.primaryColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: 24,
          ),
        ),
      ),
    );

    return enableAnimation
        ? AppAnimations.bounceIn(child: button)
        : button;
  }

  /// 載入指示器組件
  static Widget loadingIndicator({
    String? message,
    Color? color,
    double? size,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppAnimations.loadingSpinner(
            color: color ?? AppTheme.primaryColor,
            size: size ?? 32,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: color ?? AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 空狀態組件
  static Widget emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? actionButton,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppAnimations.fadeIn(
            child: Icon(
              icon,
              size: 64,
              color: AppTheme.textHintColor,
            ),
          ),
          const SizedBox(height: 16),
          AppAnimations.slideIn(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            AppAnimations.slideIn(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actionButton != null) ...[
            const SizedBox(height: 24),
            AppAnimations.scaleIn(child: actionButton),
          ],
        ],
      ),
    );
  }

  /// 成功提示組件
  static Widget successMessage({
    required String message,
    IconData icon = Icons.check_circle,
    Duration duration = const Duration(seconds: 2),
  }) {
    return AppAnimations.successAnimation(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.successColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 錯誤提示組件
  static Widget errorMessage({
    required String message,
    IconData icon = Icons.error,
    Duration duration = const Duration(seconds: 2),
  }) {
    return AppAnimations.errorAnimation(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 標籤組件
  static Widget tag({
    required String text,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: backgroundColor ?? AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? AppTheme.primaryColor,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 分割線組件
  static Widget divider({
    Color? color,
    double? thickness,
    double? height,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      height: height ?? 1,
      color: color ?? AppTheme.dividerColor,
    );
  }

  /// 間距組件
  static Widget spacing({
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
    );
  }

  /// 圓角圖片組件
  static Widget roundedImage({
    required String imageUrl,
    double? width,
    double? height,
    double? borderRadius,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ?? const Center(
              child: CircularProgressIndicator(),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? Container(
              color: AppTheme.backgroundColor,
              child: const Icon(
                Icons.error,
                color: AppTheme.errorColor,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 進度條組件
  static Widget progressBar({
    required double value,
    double? height,
    Color? backgroundColor,
    Color? progressColor,
    BorderRadius? borderRadius,
  }) {
    return Container(
      height: height ?? 8,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: progressColor != null 
                  ? [progressColor, progressColor.withOpacity(0.8)]
                  : AppTheme.primaryGradient,
            ),
            borderRadius: borderRadius ?? BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  /// 徽章組件
  static Widget badge({
    required Widget child,
    String? count,
    Color? backgroundColor,
    Color? textColor,
    double? size,
    EdgeInsetsGeometry? padding,
  }) {
    return Stack(
      children: [
        child,
        if (count != null)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: padding ?? const EdgeInsets.all(4),
              constraints: BoxConstraints(
                minWidth: size ?? 16,
                minHeight: size ?? 16,
              ),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
