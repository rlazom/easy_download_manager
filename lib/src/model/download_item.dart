import 'dart:io' show File;

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show ChangeNotifier, ValueNotifier;
import 'package:uuid/uuid.dart';

import '../common/enums.dart';

class DownloadItem extends ChangeNotifier {
  final String id;
  final String url;
  final String extendedPath;
  final percentNotifier = ValueNotifier<List<ValueNotifier<double?>>?>(null);
  final bool matchSizeWithOrigin;
  final bool parallelMultipart;
  DownloadStatusType status;
  List<CancelToken> cancelTokenList = [CancelToken()];
  File? file;

  DownloadItem({
    String? uuid,
    required this.url,
    required this.extendedPath,
    double? percent,
    this.matchSizeWithOrigin = true,
    this.parallelMultipart = true,
    this.status = DownloadStatusType.initial,
  }) : this.id = uuid ?? Uuid().v1() {
    if(percent != null) {
      percentNotifier.value = List.from([ValueNotifier<double>(percent)]);
    }
  }

  updateStatus({required DownloadStatusType newStatus}) {
    if(status != newStatus) {
      status = newStatus;
      notifyListeners();
    }
  }

  updatePercent(double newPercent, {int index = 0}) {
    percentNotifier.value![index].value = newPercent;
  }

  cancel() {
    for (CancelToken cancelToken in cancelTokenList) {
      cancelToken.cancel();
    }
    updateStatus(newStatus: DownloadStatusType.canceled);
  }

  @override
  int get hashCode {
    return url.hashCode;
  }

  @override
  bool operator ==(other) {
    return other is DownloadItem && url == other.url;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'extended_path': extendedPath,
        'percent': percentNotifier.value,
        'matchSizeWithOrigin': matchSizeWithOrigin,
        'parallel_multipart': parallelMultipart,
        'status': status.name,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> jsonMap) {
    return DownloadItem(
      uuid: jsonMap['id'],
      url: jsonMap['url'],
      extendedPath: jsonMap['extended_path'],
      percent: jsonMap['percent'],
      matchSizeWithOrigin: jsonMap['matchSizeWithOrigin'],
      parallelMultipart: jsonMap['parallel_multipart'],
      status: _downloadStatusTypeFromString(jsonMap['status']),
    );
  }

  static DownloadStatusType _downloadStatusTypeFromString(String value){
    return DownloadStatusType.values.firstWhere((e)=>
    e.name.toUpperCase() == value.toUpperCase());
  }
}
