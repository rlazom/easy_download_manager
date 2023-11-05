import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ValueNotifier, debugPrint;
import 'package:path/path.dart' as path;
import 'package:system_info2/system_info2.dart';

import '../../flex_master/data_sources/flex_master_data_source_local.dart';
import '../../flex_master/data_sources/flex_master_data_source_remote.dart';

class DownloadDataSourceRemote extends FlexMasterDataSourceRemote {
  DownloadDataSourceRemote() : super();
  final double maxAvailableMemory = 0.80; // Max limit of available memory
  final availableCores = Platform.numberOfProcessors;

  int _calculateOptimalMaxParallelDownloads(int fileSize, int maxMemoryUsage) {
    // debugPrint('_calculateOptimalMaxParallelDownloads()...');
    final maxPartSize = (maxMemoryUsage / availableCores).floor();
    final maxParallelDownloads = (fileSize / maxPartSize).ceil();

    final result = maxParallelDownloads > availableCores
        ? availableCores
        : fileSize < 2000000

            /// IF FILE SIZE < 2MB THEN 1 PARALLEL DOWNLOAD
            ? 1
            : ((maxParallelDownloads + availableCores) / 2).floor();
    return result;
  }

  Future<int> _getMaxMemoryUsage() async {
    // debugPrint('_getMaxMemoryUsage()...');

    dynamic freePhysicalMemory;
    // final totalPhysicalMemory = SysInfo.getTotalPhysicalMemory();
    try {
      freePhysicalMemory = SysInfo.getFreePhysicalMemory();
    } catch (_) {
      freePhysicalMemory = 0;
    }

    // debugPrint('_getMaxMemoryUsage() - totalPhysicalMemory: "$totalPhysicalMemory" - ${filesize(totalPhysicalMemory)}');
    // debugPrint('_getMaxMemoryUsage() - freePhysicalMemory: "$freePhysicalMemory" - ${filesize(freePhysicalMemory)}');

    final maxMemoryUsage = (freePhysicalMemory * maxAvailableMemory).round();
    return maxMemoryUsage;
  }

  Future<File?> getDownloadItemFileWithProgress(
      {required String fileUrl,
      required String fileLocalRouteStr,
      bool matchSizeWithOrigin = true,
      bool parallelMultipart = false,
      ValueNotifier<List<ValueNotifier<double?>>?>? percentListNotifier,
      String? rangeInBytes,
      List<CancelToken>? cancelTokenList}) async {
    debugPrint('DownloadDataSourceRemote - getDownloadItemFileWithProgress()...');

    cancelTokenList?.clear();
    percentListNotifier?.value = [];

    File localFile = File(fileLocalRouteStr);
    String dir = path.dirname(fileLocalRouteStr);
    String basename = path.basenameWithoutExtension(fileLocalRouteStr);
    String extension = path.extension(fileLocalRouteStr);

    debugPrint('basename: "$basename", extension: "$extension"');
    debugPrint('dir: "$dir"');

    final bool existsSync = localFile.existsSync();
    final int fileLocalSize = existsSync ? localFile.lengthSync() : 0;
    final int fileOriginSize =
        await FlexMasterDataSourceLocal().fetchFileTotalSize(fileUrl);
    final int maxMemoryUsage = await _getMaxMemoryUsage();

    int chunkSize = fileOriginSize;
    int optimalMaxParallelDownloads = 1;

    debugPrint(
        '..getDownloadItemFileWithProgress() - matchSizeWithOrigin: "$matchSizeWithOrigin", existsSync: "$existsSync"');
    if (matchSizeWithOrigin) {
      if (parallelMultipart) {
        optimalMaxParallelDownloads = maxMemoryUsage == 0
            ? 1
            : _calculateOptimalMaxParallelDownloads(
                fileOriginSize, maxMemoryUsage);
        chunkSize = (chunkSize / optimalMaxParallelDownloads).ceil();

        File chunkSizeFile = File('$dir/_chunkSize_$basename');
        if (!chunkSizeFile.existsSync()) {
          // debugPrint('_download() - Creating chunkSizeFile...');
          chunkSizeFile.createSync(recursive: true);
          chunkSizeFile.writeAsStringSync(chunkSize.toString());
          // debugPrint('_download() - Creating chunkSizeFile... DONE');
        } else {
          // debugPrint('_download() - Reading chunkSize from chunkSizeFile...');
          chunkSize = int.parse(chunkSizeFile.readAsStringSync());
        }

        File optimalMaxParallelDownloadsFile =
            File('$dir/_maxParallelDownloads_$basename');
        if (!optimalMaxParallelDownloadsFile.existsSync()) {
          // debugPrint('_download() - Creating optimalMaxParallelDownloadsFile...');
          optimalMaxParallelDownloadsFile.createSync(recursive: true);
          optimalMaxParallelDownloadsFile
              .writeAsStringSync(optimalMaxParallelDownloads.toString());
          // debugPrint('_download() - Creating optimalMaxParallelDownloadsFile... DONE');
        } else {
          // debugPrint('_download() - Reading optimalMaxParallelDownloads from optimalMaxParallelDownloadsFile...');
          optimalMaxParallelDownloads =
              int.parse(optimalMaxParallelDownloadsFile.readAsStringSync());
        }
      }
    }

    if (fileLocalSize < fileOriginSize) {
      final List<Future> tasks = [];
      List<ValueNotifier<double?>> tempNotifier = [];
      for (int i = 0; i < optimalMaxParallelDownloads; i++) {
        tempNotifier.add(ValueNotifier<double?>(null));
        percentListNotifier?.value = List.from(tempNotifier);
        cancelTokenList?.add(CancelToken());
        final start = i * chunkSize;
        var end = (i + 1) * chunkSize - 1;
        if (existsSync && end > fileLocalSize - 1) {
          end = fileLocalSize - 1;
        }

        String fileName = '$dir/$basename' '_$i';
        debugPrint(
            '_download() - [index: "$i"] - fileName: "${path.basename(fileName)}", fileOriginChunkSize: "${end - start}", start: "$start", end: "$end"');
        final Future<File?> task = getChunkFileWithProgress(
            fileUrl: fileUrl,
            fileLocalRouteStr: fileName,
            fileOriginChunkSize: end - start,
            percentNotifier: percentListNotifier?.value?.elementAt(i),
            cancelToken: cancelTokenList?.elementAt(i),
            start: start,
            end: end,
            index: i);
        tasks.add(task);
      }

      List? results;
      try {
        debugPrint('_download() - TRY await Future.wait(tasks)...');
        results = await Future.wait(tasks);
      } catch (e) {
        debugPrint(
            '_download() - TRY await Future.wait(tasks) - ERROR: "${e.toString()}"');
        return null;
      }
      debugPrint('_download() - TRY await Future.wait(tasks)...DONE');

      /// WRITE BYTES
      if (results.isNotEmpty) {
        debugPrint('_download() - MERGING...');
        for (File result in results) {
          debugPrint(
              '_download() - MERGING - file: "${path.basename(result.path)}"...');
          localFile.writeAsBytesSync(
            result.readAsBytesSync(),
            mode: FileMode.writeOnlyAppend,
          );
          result.delete();
        }
        debugPrint('_download() - MERGING...DONE');

        List<FileSystemEntity>? files;
        String dir = path.dirname(fileLocalRouteStr);
        final localDir = Directory(dir);
        files = localDir.listSync(
          recursive: true,
          followLinks: false,
        );
        for (FileSystemEntity file in files) {
          if (file is File) {
            String filepath = file.path;
            String basename = path.basename(filepath);
            if (basename.startsWith('_')) {
              file.delete();
            }
          }
        }
      }
    } else {
      percentListNotifier?.value = List.from([ValueNotifier<double>(1.0)]);
      debugPrint('_download() - [ALREADY DOWNLOADED]');
    }

    // debugPrint('..DownloadDataSourceRemote - getDownloadItemFileWithProgress() - return localFile');
    return localFile;
  }

  Future<File?> getChunkFileWithProgress({
    required String fileUrl,
    required String fileLocalRouteStr,
    required int fileOriginChunkSize,
    ValueNotifier<double?>? percentNotifier,
    CancelToken? cancelToken,
    int start = 0,
    int? end,
    int index = 0,
  }) async {
    debugPrint('DownloadDataSourceRemote - getChunkFileWithProgress()...');

    File localFile = File(fileLocalRouteStr);
    String dir = path.dirname(fileLocalRouteStr);
    String basename = path.basenameWithoutExtension(fileLocalRouteStr);

    // debugPrint('getChunkFileWithProgress(index: "$index") - basename: "$basename"...');
    String localRouteToSaveFileStr = fileLocalRouteStr;
    List<int> sizes = [];
    Options options = Options(
      headers: {'Range': 'bytes=$start-$end'},
    );

    int sumSizes = 0;
    bool existsSync = localFile.existsSync();
    // debugPrint('getChunkFileWithProgress(index: "$index") - existsChunk: "$existsSync');
    if (existsSync) {
      int fileLocalSize = localFile.lengthSync();
      // debugPrint('getChunkFileWithProgress(index: "$index") - existsChunk: "$basename", fileLocalSize: "$fileLocalSize" - ${filesize(fileLocalSize)}');
      sizes.add(fileLocalSize);

      int i = 1;
      localRouteToSaveFileStr = '$dir/$basename' '_$i.part';
      File f = File(localRouteToSaveFileStr);
      while (f.existsSync()) {
        int chunkSize = f.lengthSync();
        // debugPrint(
        //     'getChunkFileWithProgress(index: "$index") - existsChunk: "$basename'
        //         '_$i.part", chunkSize: "$chunkSize" - ${filesize(chunkSize)}');
        sizes.add(chunkSize);
        i++;
        localRouteToSaveFileStr = '$dir/$basename' '_$i.part';
        f = File(localRouteToSaveFileStr);
      }

      sumSizes = sizes.fold(0, (p, c) => p + c);
      if (sumSizes < fileOriginChunkSize) {
        // debugPrint('getChunkFileWithProgress(index: "$index") - CREATING Chunk: "$basename''_$i.part"');
        // int starBytes = start + sumSizes;
        // debugPrint('getChunkFileWithProgress(index: "$index") - FETCH Options: sumSizes: "$sumSizes", start: "$start", end: "$end"');
        // debugPrint('getChunkFileWithProgress(index: "$index") - FETCH Options: "bytes=$starBytes-$end"');
        options = Options(
          headers: {'Range': 'bytes=${start + sumSizes}-$end'},
        );
      } else {
        // List tempList = percentNotifier.value!;
        // tempList[index] = 1.0;
        // percentNotifier.value = List.from(tempList);
        // percentNotifier.notifyListeners();

        percentNotifier?.value = 1.0;

        // debugPrint('getChunkFileWithProgress(index: "$index") - [ALREADY DOWNLOADED]');
        if (sizes.length == 1) {
          // debugPrint('getChunkFileWithProgress(index: "$index") - [ALREADY DOWNLOADED - ONE FILE]');
          // _checkOnLocal(fileUrl: fileUrl, fileLocalRouteStr: fileLocalRouteStr);
          return localFile;
        }
      }
    }

    if ((percentNotifier?.value ?? 0) < 1) {
      // CancelToken cancelToken = cancelTokenList.elementAt(index);
      if (cancelToken?.isCancelled ?? true) {
        cancelToken = CancelToken();
      }

      try {
        debugPrint(
            'getChunkFileWithProgress(index: "$index") - TRY dio.download()...');
        await Dio().download(fileUrl, localRouteToSaveFileStr,
            options: options,
            cancelToken: cancelToken,
            deleteOnError: false,
            onReceiveProgress: (int received, int total) => _onReceiveProgress(
                received + sumSizes,
                fileOriginChunkSize,
                cancelToken,
                percentNotifier));
      } catch (e) {
        debugPrint(
            'getChunkFileWithProgress(index: "$index") - TRY dio.download() - ERROR: "${e.toString()}"');
        // return null;
        rethrow;
      }
    }

    if (existsSync) {
      debugPrint(
          'getChunkFileWithProgress(index: "$index") - CHUNKS DOWNLOADED - MERGING FILES...');
      var raf = await localFile.open(mode: FileMode.writeOnlyAppend);

      int i = 1;
      String filePartLocalRouteStr = '$dir/$basename' '_$i.part';
      File f = File(filePartLocalRouteStr);
      while (f.existsSync()) {
        // raf = await raf.writeFrom(await f.readAsBytes());
        await raf.writeFrom(await f.readAsBytes());
        await f.delete();

        i++;
        filePartLocalRouteStr = '$dir/$basename' '_$i.part';
        f = File(filePartLocalRouteStr);
      }
      await raf.close();
    }

    return localFile;
  }

  _onReceiveProgress(int received, int total, CancelToken? cancelToken,
      ValueNotifier? percentNotifier) {
    if (cancelToken != null &&
        !cancelToken.isCancelled &&
        percentNotifier != null) {
      var valueNew = received / total;
      percentNotifier.value = valueNew;
    }
  }
}
