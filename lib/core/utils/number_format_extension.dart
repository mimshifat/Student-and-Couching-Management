extension NumberFormatExtension on num {
  String toCleanString({int maxDecimals = 1}) {
    String str = toStringAsFixed(maxDecimals);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0*$'), '');
      str = str.replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }
}
