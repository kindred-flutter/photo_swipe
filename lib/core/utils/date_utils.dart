import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _fullFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _dateOnly = DateFormat('yyyy-MM-dd');

  static String formatFull(DateTime? dt) {
    if (dt == null) return '未知时间';
    return _fullFormat.format(dt);
  }

  static String formatDate(DateTime dt) => _dateOnly.format(dt);

  static String formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} 个月前';
    return '${(diff.inDays / 365).floor()} 年前';
  }

  static String formatExpiry(DateTime expireAt) {
    final diff = expireAt.difference(DateTime.now());
    if (diff.isNegative) return '已过期';
    if (diff.inDays == 0) return '今天过期';
    return '${diff.inDays} 天后过期';
  }
}
