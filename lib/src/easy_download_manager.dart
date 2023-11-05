import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show File;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:easy_download_manager/src/common/extensions.dart';
import 'package:easy_download_manager/src/common/general_functions.dart';
import 'package:easy_download_manager/src/repository/download/download_repository.dart';
import 'package:easy_download_manager/src/services/shared_preferences_service.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
// import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'common/enums.dart';
import 'model/download_item.dart';


class EasyDownloadManager extends ChangeNotifier {
  bool initialized = false;
  final SharedPreferencesService _shared = SharedPreferencesService();
  late DownloadRepository downloadRepository;
  List<DownloadItem> _currentDownloads = [];
  final Queue<DownloadItem> _queue = Queue();
  int maxParallelDownloads;
  late String path;

  EasyDownloadManager({this.maxParallelDownloads = 5});

  int get currentParallelDownloads => _currentDownloads.length;

  Future<void> initialize() async {
    if (!initialized) {
      List<Future> list = [
        _shared.initialize(),
        GeneralFunctions().getDirectoryType().then((dir) => path = dir.path)
      ];

      await Future.wait(list);
      downloadRepository = DownloadRepository(directoryPath: path);
      initialized = true;
    }

    _loadDataFromSharedPrefs();
    if (arePendingDownloads()) {
      reStart();
    }
  }

  void _loadDataFromSharedPrefs() {
    final keysCurrent = _shared.getSmallDownloadCurrentListDataKeys();
    final keysQueue = _shared.getSmallDownloadQueueDataKeys();

    final tempListCurrent = _loadKeyValueData(keysCurrent);
    final tempListQueue = _loadKeyValueData(keysQueue);

    if (tempListCurrent.isNotEmpty) {
      _currentDownloads = List.from(tempListCurrent.toSet());
    }
    if (tempListQueue.isNotEmpty) {
      _queue.addAll(List.from(tempListQueue.toSet()));
    }
  }

  bool _existsInQueue(DownloadItem downloadItem) {
    // debugPrint('DownloadList - _existsInQueue(urlFileName: "${downloadItem.url.toString().urlFileName}")');
    return _queue.contains(downloadItem) ||
        _currentDownloads.contains(downloadItem);
  }

  DownloadItem _getFromQueue(DownloadItem downloadItem) {
    DownloadItem? tItem =
        _queue.firstWhereOrNull((element) => element == downloadItem);
    tItem = tItem ??
        _currentDownloads
            .firstWhereOrNull((element) => element == downloadItem);
    return tItem!;
  }

  Future<DownloadItem?> getFromStorage(
      {required String url, required String extendedPath}) async {
    File? fileInStorage = await downloadRepository.getDownloadItemFileWithProgress(
      fileUrl: url,
      extendedPath: extendedPath,
      source: SourceType.LOCAL,
    );

    if (fileInStorage != null) {
      DownloadItem downloadItem = DownloadItem(
        url: url,
        extendedPath: extendedPath,
      );
      downloadItem.file = fileInStorage;
      downloadItem.updateStatus(newStatus: DownloadStatusType.downloaded);
      return downloadItem;
    }
    return null;
  }

  DownloadItem? getFromPending(
      {required String url, required String extendedPath}) {
    DownloadItem item = DownloadItem(
      url: url,
      extendedPath: extendedPath,
    );
    bool existsInQueue = _existsInQueue(item);
    if (existsInQueue) {
      item = _getFromQueue(item);
      return item;
    }
    return null;
  }

  bool arePendingDownloads() {
    return currentParallelDownloads > 0;
  }

  reStart() {
    for (DownloadItem item in _currentDownloads) {
      item.cancel();
      _start(item);
    }
  }

  Future<DownloadItem?> add(
      {required String? url, required String extendedPath}) async {
    String? urlFileName = url?.toString().urlFileName;
    debugPrint('DownloadList - add(urlFileName: "$urlFileName")...');

    if (url == null) {
      return null;
    }

    DownloadItem item = DownloadItem(
      url: url,
      extendedPath: extendedPath,
      parallelMultipart: false,
    );

    debugPrint('DownloadList - add(urlFileName: "$urlFileName") - _existsInQueue()...');
    bool existsInQueue = _existsInQueue(item);
    debugPrint('DownloadList - add(urlFileName: "$urlFileName") - existsInQueue: "$existsInQueue"');
    if (existsInQueue) {
      item = _getFromQueue(item);
    } else {
      item.updateStatus(newStatus: DownloadStatusType.queued);
      _queue.add(item);
      _shared.addSmallDownloadQueueData(json.encode(item), item.id);
      notifyListeners();

      debugPrint('..add() - _currentDownloads: ${_currentDownloads.length}');
      debugPrint('..add() - _queue: ${_queue.length}');
      debugPrint('..add()... _canStart(): "${_canStart()}"');

      if (_canStart()) {
        _next();
      }
    }

    item.notifyListeners();
    return item;
  }

  bool _canStart() {
    bool canStart =
        currentParallelDownloads < maxParallelDownloads && _queue.isNotEmpty;
    // debugPrint('DownloadList - _canStart() = $canStart');
    return canStart;
  }

  _next() {
    // debugPrint('DownloadList - _next()');
    DownloadItem item = _removeFromQueue();
    _currentDownloads.add(item);
    _shared.addSmallDownloadCurrentListData(json.encode(item), item.id);

    _start(item);
  }

  _start(DownloadItem item) {
    // debugPrint('DownloadList - _start(urlFileName: "${item.url.toString().urlFileName}")');
    item.updateStatus(newStatus: DownloadStatusType.downloading);
    downloadRepository
        .getDownloadItemFileWithProgress(
          fileUrl: item.url,
          extendedPath: item.extendedPath,
          matchSizeWithOrigin: item.matchSizeWithOrigin,
          parallelMultipart: item.parallelMultipart,
          percentListNotifier: item.percentNotifier,
          cancelTokenList: item.cancelTokenList,
        )
        .then((file) => _handleOnItemFinish(item, file));
  }

  _handleOnItemFinish(DownloadItem currentItem, File? file) {
    // debugPrint('DownloadList - _handleOnItemFinish(urlFileName: "${currentItem.url.toString().urlFileName}")...');
    if (file != null) {
      currentItem.file = file;
    }

    currentItem.updateStatus(newStatus: DownloadStatusType.downloaded);
    currentItem.notifyListeners();
    _currentDownloads.remove(currentItem);
    _shared.removeSmallDownloadCurrentListData(currentItem.id);

    // debugPrint('.._handleOnItemFinish()... _canStart(): "${_canStart()}"');
    if (_canStart()) {
      _next();
    }
    // debugPrint('.._currentDownloads: ${_currentDownloads.length}');
    // debugPrint('.._queue: ${_queue.length}');
    // debugPrint('.._handleOnItemFinish()... DONE');
  }

  DownloadItem _removeFromQueue() {
    DownloadItem removedItem = _queue.removeFirst();
    _shared.removeSmallDownloadCurrentListData(removedItem.id);
    notifyListeners();
    return removedItem;
  }

  List<DownloadItem> _loadKeyValueData(List<String> keys) {
    List<DownloadItem> tempList = [];

    if (keys.isNotEmpty) {
      for (String key in keys) {
        var response = _shared.getSmallDownloadData(key);
        if (response != null) {
          DownloadItem di = DownloadItem.fromJson(json.decode(response));
          tempList.add(di);
        }
      }
    }

    return tempList;
  }
}
