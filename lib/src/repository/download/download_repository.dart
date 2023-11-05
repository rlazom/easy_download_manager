import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ValueNotifier;

import '../../common/enums.dart';
import '../../common/general_functions.dart';
import 'data_sources/download_data_source_local.dart';
import 'data_sources/download_data_source_remote.dart';

class DownloadRepository {
  final dynamic local = DownloadDataSourceLocal();
  final dynamic remote = DownloadDataSourceRemote();
  final String directoryPath;

  // final String extendedPath;

  // DownloadRepository({required this.directoryPath, required this.extendedPath});
  DownloadRepository({required this.directoryPath});

  Future<File?> getItemFile({
    required String fileUrl,
    bool matchSizeWithOrigin = true,
    String extendedPath = '',
  }) async {
    String fileLocalRouteStr = GeneralFunctions().getLocalCacheFilesRoute(
      fileUrl,
      directoryPath: directoryPath,
      extendedPath: extendedPath,
    );

    Map<SourceType, Function> allSources = {
      SourceType.LOCAL: local.getItemFile,
      SourceType.REMOTE: remote.getItemFile,
    };

    File? response;
    for (Function fn in allSources.values) {
      try {
        response = await fn(
          fileUrl: fileUrl,
          fileLocalRouteStr: fileLocalRouteStr,
          matchSizeWithOrigin: matchSizeWithOrigin,
        );
      } catch (e) {
        rethrow;
      }

      if (response != null) {
        break;
      }
    }

    return response;
  }

  Future<File?> getDownloadItemFileWithProgress(
      {required String fileUrl,
        required String extendedPath,
      bool matchSizeWithOrigin = true,
      bool parallelMultipart = false,
      ValueNotifier<List<ValueNotifier<double?>>?>? percentListNotifier,
      String? rangeInBytes,
      List<CancelToken>? cancelTokenList,
      SourceType? source,}) async {
    String fileLocalRouteStr = GeneralFunctions().getLocalCacheFilesRoute(
      fileUrl,
      directoryPath: directoryPath,
      extendedPath: extendedPath,
    );

    Map<SourceType, Function> allSources = {
      SourceType.LOCAL: local.getDownloadItemFileWithProgress,
      SourceType.REMOTE: remote.getDownloadItemFileWithProgress,
    };
    Map<SourceType, Function> sources = {};
    if (source != null) {
      sources = {source: allSources[source]!};
    } else {
      sources = allSources;
    }

    File? response;
    for (Function fn in sources.values) {
      try {
        response = await fn(
            fileUrl: fileUrl,
            fileLocalRouteStr: fileLocalRouteStr,
            matchSizeWithOrigin: matchSizeWithOrigin,
            parallelMultipart: parallelMultipart,
            percentListNotifier: percentListNotifier,
            rangeInBytes: rangeInBytes,
            cancelTokenList: cancelTokenList);
      } catch (e) {
        rethrow;
      }

      if (response != null) {
        break;
      }
    }

    return response;
  }
}
