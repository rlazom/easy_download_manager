import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ValueNotifier;

import '../../flex_master/data_sources/flex_master_data_source_local.dart';

class DownloadDataSourceLocal extends FlexMasterDataSourceLocal {

  DownloadDataSourceLocal() : super();

  Future<File?> getDownloadItemFileWithProgress(
          {required String fileUrl,
          required String fileLocalRouteStr,
          bool matchSizeWithOrigin = true,
          bool parallelMultipart = false,
          ValueNotifier<List<ValueNotifier<double?>>?>? percentListNotifier,
          String? rangeInBytes,
          List<CancelToken>? cancelTokenList}) async =>
      await getItemFile(
        fileUrl: fileUrl,
        fileLocalRouteStr: fileLocalRouteStr,
        matchSizeWithOrigin: matchSizeWithOrigin,
      );
}
