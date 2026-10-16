import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

typedef ShareLogFile = Future<void> Function(File file, Rect? origin);

/// Opens the system share sheet with one log file. [origin] anchors the
/// popover on iPad.
Future<void> shareLogFile(File file, Rect? origin) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/plain')],
    sharePositionOrigin: origin,
  ));
}
