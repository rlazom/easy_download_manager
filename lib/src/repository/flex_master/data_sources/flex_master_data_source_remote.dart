import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show debugPrint;

class FlexMasterDataSourceRemote {

  FlexMasterDataSourceRemote() : super();

  Future<File?> getItemFile(
      {required String fileUrl, required String fileLocalRouteStr, bool matchSizeWithOrigin = true}) async {
    File localFile = File(fileLocalRouteStr);
    // print('FlexMasterDataSourceRemote - getItemFile() - fileUrl: $fileUrl, fileLocalRouteStr: $fileLocalRouteStr');

    var dio = Dio();
    try {
      await dio.download(fileUrl, fileLocalRouteStr);
    } catch (e) {
      debugPrint('FlexMasterDataSourceRemote - getItemFile() - CATCH ERROR: "${e.toString()}"');
      debugPrint('FlexMasterDataSourceRemote - getItemFile() - CATCH ERROR - url: "$fileUrl"');
      return null;
    }
    return localFile;
  }
}
