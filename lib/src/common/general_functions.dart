import 'dart:io' show Directory;
import 'package:diacritic/diacritic.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'enums.dart';

class GeneralFunctions {
  String getBaseUrl(video) {
    final parse = Uri.parse(video);
    final uri = parse.query != '' ? parse.replace(query: '') : parse;
    String url = uri.toString();
    if (url.endsWith('?')) url = url.replaceAll('?', '');
    return url;
  }

  String getLocalCacheFilesRoute(String url, {String extendedPath = '', required String directoryPath}) {
    url = removeDiacritics(Uri.decodeFull(url)).replaceAll(' ', '_');
    var baseUrl = getBaseUrl(url);
    String fileBaseName = path.basename(baseUrl);
    return path.join(directoryPath, extendedPath, fileBaseName);
  }

  Future<Directory> getDirectoryType({DirectoryType directoryType = DirectoryType.CACHE}) {
    switch (directoryType) {
      case DirectoryType.APP_DOCUMENTS:
        {
          return getApplicationDocumentsDirectory();
        }

      case DirectoryType.CACHE:
        {
          return getTemporaryDirectory();
        }

      default:
        {
          return getTemporaryDirectory();
        }
    }
  }
}