import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../data/word_repository.dart';

enum LogShareStatus {
  success,
  dismissed,
  unavailable,
}

class LogShareOutcome {
  const LogShareOutcome(this.status);

  final LogShareStatus status;
}

abstract class LogShareService {
  Future<LogShareOutcome> share(
    LogExportResult export, {
    Rect? sharePositionOrigin,
  });
}

class PlatformLogShareService implements LogShareService {
  const PlatformLogShareService();

  @override
  Future<LogShareOutcome> share(
    LogExportResult export, {
    Rect? sharePositionOrigin,
  }) async {
    final text = 'Expat8 mobile logs (${export.count} entries)';
    const subject = 'Expat8 mobile logs';
    final result = export.path == null
        ? await Share.share(
            export.payload,
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          )
        : await Share.shareXFiles(
            [
              XFile(
                export.path!,
                mimeType: export.mimeType,
                name: export.fileName,
              ),
            ],
            text: text,
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          );
    return LogShareOutcome(_mapStatus(result.status));
  }

  LogShareStatus _mapStatus(ShareResultStatus status) {
    return switch (status) {
      ShareResultStatus.success => LogShareStatus.success,
      ShareResultStatus.dismissed => LogShareStatus.dismissed,
      ShareResultStatus.unavailable => LogShareStatus.unavailable,
    };
  }
}
