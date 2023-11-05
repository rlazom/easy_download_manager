import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'dart:io' show File, SocketException;
import 'package:flutter/foundation.dart' show compute;

import '../../../services/shared_preferences_service.dart';

class FlexMasterDataSourceLocal {
  final SharedPreferencesService shared = SharedPreferencesService();

  FlexMasterDataSourceLocal();

  Future<int> fetchFileTotalSize(fileUrl) async {
    int fileSize = -1;
    Response response;
    Response defaultResponse = Response(requestOptions: RequestOptions(path: '', headers: {'Content-Range': '0/-1'}));
    try {
      response = await Dio().get(
          fileUrl, options: Options(headers: {'Range': 'bytes=0-0'}));
    } on SocketException catch (_) {
      response = defaultResponse;
    } on TimeoutException catch (_) {
      response = defaultResponse;
    } catch (error) {
      response = defaultResponse;
    }

    String? contentRange = response.headers.value('Content-Range');
    if(contentRange != null) {
      contentRange = contentRange.split('/').last;
      fileSize = int.parse(contentRange);
    }
    return fileSize;
  }

  Future<String> fetchFileChecksum(fileUrl) async {
    // print('FlexMasterDataSourceLocal - fetchFileChecksum(fileUrl: "$fileUrl")');
    String checksum = '';
    Response response;
    Response defaultResponse = Response(requestOptions: RequestOptions(path: '', headers: {'ETag': ''}));
    try {
      response = await Dio().get(
          fileUrl, options: Options(headers: {'Range': 'bytes=0-0'}));
    } on SocketException catch (_) {
      response = defaultResponse;
    } on TimeoutException catch (_) {
      response = defaultResponse;
    } catch (error) {
      response = defaultResponse;
    }

    String? eTag = response.headers.value('ETag');
    if(eTag != null) {
      checksum = eTag.replaceAll('"', '');
    }
    return checksum;
  }

  bool _checkFileMatched(String localFilePath) {
    List<String> list = shared.getCheckedMediaData();
    // print('FlexMasterDataSourceLocal - _checkFileMatched(localFilePath: "$localFilePath") - fileMatched - "${list.contains(localFilePath)}"');
    return list.contains(localFilePath);
  }

  bool _checkFileChecksum(String localFilePath) {
    List<String> list = shared.getCheckedDataChecksum();
    // print('FlexMasterDataSourceLocal - _checkFileChecksum(localFilePath: "$localFilePath") - checksumMatched - "${list.contains(localFilePath)}"');
    return list.contains(localFilePath);
  }

  String _localChecksumGeneration(Map map) {
    File localFile = map['file'];
    String crypt = map['crypt'];

    Digest digest;
    final localBytes = localFile.readAsBytesSync();
    if(crypt == 'sha1') {
      digest =  sha1.convert(localBytes);
    } else if(crypt == 'sha256') {
      digest =  sha256.convert(localBytes);
    } else if(crypt == 'sha512') {
      digest =  sha512.convert(localBytes);
    } else if(crypt == 'md5') {
      digest = md5.convert(localBytes);
    } else {
      digest = md5.convert(localBytes);
    }

    return digest.toString();
  }

  Future<String> _isolatedChecksumGeneration(File localFile, {String crypt = 'md5'}) async {
    return await compute(_localChecksumGeneration, {'file':localFile,'crypt':crypt});
  }

  Future<File?> getItemFile(
      {required String fileUrl, required String fileLocalRouteStr, bool matchSizeWithOrigin = true}) async {
    File localFile = File(fileLocalRouteStr);
    // print('FlexMasterDataSourceLocal - getItemFile() - fileUrl: "${fileUrl.split('/').last.split('?').first}" - localFile: "${localFile.path}", localFile.existsSync(): "${localFile.existsSync()}"');
    if (localFile.existsSync()) {
      // String fileName = fileUrl.split('/').last.split('?').first.toString().trim();
      int fileLocalSize = localFile.lengthSync();
      bool fileSizeChecked = matchSizeWithOrigin ? _checkFileMatched(localFile.path) : true;
      bool fileChecksumChecked = matchSizeWithOrigin ? _checkFileChecksum(localFile.path) : true;
      int fileOriginSize = (!matchSizeWithOrigin || fileSizeChecked) ? fileLocalSize : await fetchFileTotalSize(fileUrl);

      final localChecksum = !matchSizeWithOrigin || fileChecksumChecked ? '-' : await _isolatedChecksumGeneration(localFile);
      final originChecksum = (!matchSizeWithOrigin || fileChecksumChecked) ? localChecksum : await fetchFileChecksum(fileUrl);

      bool returnLocalFile = false;

      // print('FlexMasterDataSourceLocal - getItemFile() '
      //     '\nfileName: "$fileName", '
      //     '\nfileUrl: "$fileUrl", '
      //     '\nmatchSizeWithOrigin: "$matchSizeWithOrigin", '
      //     '\nfileLocalSize/fileOriginSize: "$fileLocalSize/$fileOriginSize" - '
      //     'SIZE CHECK: "${fileLocalSize == fileOriginSize}" _fileSizeChecked: "$_fileSizeChecked", '
      //     '\nlocalChecksum/originChecksum: "$localChecksum/$originChecksum" - '
      //     'CHECKSUM CHECK: "${localChecksum == originChecksum}", _fileChecksumChecked: "$_fileChecksumChecked"'
      //     '\n.');
      fileOriginSize = fileOriginSize == -1 ? fileLocalSize : fileOriginSize;

      // print('FlexMasterDataSourceLocal - getItemFile() '
      //     '\nfileName: "$fileName", '
      //     '\nfileLocalSize/fileOriginSize: "$fileLocalSize/$fileOriginSize", '
      //     'SIZE CHECK: "${fileLocalSize == fileOriginSize}" _fileSizeChecked: "$_fileSizeChecked", ');
      if(fileLocalSize > 0 && fileLocalSize == fileOriginSize) {
        if(matchSizeWithOrigin && !fileSizeChecked) {
          shared.addCheckedMediaData(localFile.path);
        }
        returnLocalFile = true;
      }
      if(originChecksum.isNotEmpty) {
        if(localChecksum == originChecksum) {
          if(matchSizeWithOrigin && !fileChecksumChecked) {
            shared.addCheckedDataChecksum(localFile.path);
          }
          returnLocalFile = true;
        } else {
          returnLocalFile = false;
        }
      }

      if(returnLocalFile) {
        return localFile;
      }
    }
    return null;
  }
}
