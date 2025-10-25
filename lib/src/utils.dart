String bytesToHumanReadableString(int bytes) {
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var index = 0;
  while (size >= 1024 && index < suffixes.length - 1) {
    size /= 1024;
    index++;
  }
  return '${size.toStringAsFixed(2)} ${suffixes[index]}';
}
