import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

class FlexImage extends StatelessWidget {
  final File imageFile;
  final double imgSize;
  final BoxFit? boxFit;

  const FlexImage({
    Key? key,
    required this.imageFile,
    this.imgSize = 30.0,
    this.boxFit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final BoxFit boxFit = this.boxFit ?? BoxFit.fitWidth;
    if (p.extension(imageFile.path).toLowerCase() != '.svg') {
      return Image.file(
        imageFile,
        width: imgSize,
        height: imgSize,
        fit: boxFit,
      );
    } else {
      return SvgPicture.file(
        imageFile,
        fit: boxFit,
        width: imgSize + 8,
        height: imgSize + 8,
      );
    }
  }
}
