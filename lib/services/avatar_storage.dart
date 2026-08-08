import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies a picked photo into the app's own documents directory so the
/// saved path stays valid across launches -- image_picker's returned path
/// can point into a cache directory the OS is free to clear at any time.
class AvatarStorage {
  static Future<String> persist(String pickedPath, String playerColorName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${docsDir.path}/ludo_avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    final ext = pickedPath.split('.').last;
    final destPath = '${avatarsDir.path}/${playerColorName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(pickedPath).copy(destPath);
    return destPath;
  }
}
