import 'package:flutter/foundation.dart';

class DeletePhotoSession {
  final ValueNotifier<bool> undone;
  final String trashItemId;

  DeletePhotoSession({
    required this.undone,
    required this.trashItemId,
  });
}
