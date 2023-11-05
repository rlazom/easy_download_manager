import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

extension StringX on String {
  Color hexToColor() =>
      Color(int.parse(substring(1, 7), radix: 16) + 0xFF000000);

  int toInt() => int.parse(this);

  Uri toUri() => Uri.parse(this);

  String toShortString() {
    return split('.').last.toLowerCase();
  }

  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }

  DateTime fromTimeStamp() {
    return DateTime.fromMillisecondsSinceEpoch(toInt() * 1000);
  }

  String get normalize {
    String decodedUrl = Uri.decodeFull(this);
    return path.normalize(decodedUrl);
  }
}

extension StringNullX on String? {
  String? get urlFileName {
    return this?.split('?').first.split('/').last.trim();
  }
}
