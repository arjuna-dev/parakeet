String accessBigJson(Map<String, dynamic> listWithBigJson, String filename) {
  print("listWithBigJson: $listWithBigJson");
  final pattern = RegExp(r'(\D+)|(\d+)');
  final matches = pattern.allMatches(filename);

  dynamic currentMap = listWithBigJson;
  for (var match in matches) {
    final key = match.group(0)!;
    final cleanedKey = key.replaceAll(RegExp(r'^_|_$'), '');

    if (int.tryParse(cleanedKey) != null) {
      // If it's a number, parse it as an index
      int index = int.parse(cleanedKey);
      currentMap = currentMap[index];
    } else {
      // If it's not a number, use it as a string key
      currentMap = currentMap[cleanedKey];
    }

    // If at any point currentMap is null, the key filename is invalid
    if (currentMap == null) {
      throw Exception("Invalid path: $filename");
    }
  }
  return currentMap;
}
