import 'dart:async';
import 'dart:convert';
import 'package:easy_download_manager/src/common/extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SharePrefsAttribute {
  checkedMediaData,
  checkedMediaChecksum,
  downloadCurrent,
  downloadQueue,
}

class SharedPreferencesService {
  /// singleton boilerplate
  static final SharedPreferencesService _sharedPreferencesService = SharedPreferencesService._internal();

  factory SharedPreferencesService() {
    return _sharedPreferencesService;
  }

  SharedPreferencesService._internal();
  /// singleton boilerplate

  late SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;

  Future initialize() async => _prefs = await SharedPreferences.getInstance();

  /// CHECKED MEDIA
  List<String> getCheckedMediaData() {

    List<String> list = [];
    String? checkedMediaStr = prefs.getString(SharePrefsAttribute.checkedMediaData.name.toShortString());
    if(checkedMediaStr != null) {
      List tList = json.decode(checkedMediaStr) as List;
      list = List.from(tList);
    }
    return list;
  }

  void addCheckedMediaData(String localFilePath) {
    Set<String> list = getCheckedMediaData().toSet();
    list.add(localFilePath);
    prefs.setString(SharePrefsAttribute.checkedMediaData.name.toShortString(), json.encode(list.toList()));
  }

  void removeCheckedMediaData(String localFilePath) {
    Set<String> list = getCheckedMediaData().toSet();
    list.remove(localFilePath);
    prefs.setString(SharePrefsAttribute.checkedMediaData.name.toShortString(), json.encode(list.toList()));
  }

  /// CHECKED CHECKSUM
  List<String> getCheckedDataChecksum() {

    List<String> list = [];
    String? checkedMediaStr = prefs.getString(SharePrefsAttribute.checkedMediaChecksum.name.toShortString());
    if(checkedMediaStr != null) {
      List tList = json.decode(checkedMediaStr) as List;
      list = List.from(tList);
    }
    return list;
  }

  void addCheckedDataChecksum(String localFilePath) {
    Set<String> list = getCheckedDataChecksum().toSet();
    list.add(localFilePath);
    prefs.setString(SharePrefsAttribute.checkedMediaChecksum.name.toShortString(), json.encode(list.toList()));
  }

  void removeCheckedDataChecksum(String localFilePath) {
    Set<String> list = getCheckedDataChecksum().toSet();
    list.remove(localFilePath);
    prefs.setString(SharePrefsAttribute.checkedMediaChecksum.name.toShortString(), json.encode(list.toList()));
  }

  /// DOWNLOAD DATA
  List<String> getSmallDownloadQueueDataKeys() {
    Set<String> keys = prefs.getKeys();
    keys.retainWhere((element) => element.contains(SharePrefsAttribute.downloadQueue.name.toShortString()));
    return keys.toList();
  }
  List<String> getSmallDownloadCurrentListDataKeys() {
    Set<String> keys = prefs.getKeys();
    keys.retainWhere((element) => element.contains(SharePrefsAttribute.downloadCurrent.name.toShortString()));
    return keys.toList();
  }

  void removeSmallDownloadQueueData(String id) {
    prefs.remove('${SharePrefsAttribute.downloadQueue.name.toShortString()}$id');
  }
  void addSmallDownloadQueueData(String json, String id) {
    prefs.setString('${SharePrefsAttribute.downloadQueue.name.toShortString()}$id', json);
  }

  void removeSmallDownloadCurrentListData(String id) {
    prefs.remove('${SharePrefsAttribute.downloadCurrent.name.toShortString()}$id');
  }
  void addSmallDownloadCurrentListData(String json, String id) {
    prefs.setString('${SharePrefsAttribute.downloadCurrent.name.toShortString()}$id', json);
  }

  String? getSmallDownloadData(String id) {
    return prefs.getString(id);
  }
}
