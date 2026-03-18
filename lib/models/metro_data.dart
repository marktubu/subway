class MetroData {
  final String city;
  final List<MetroLine> lines;
  final List<MetroTransfer> transfers;

  MetroData({required this.city, required this.lines, required this.transfers});

  factory MetroData.fromJson(Map<String, dynamic> json) {
    return MetroData(
      city: json['city'] as String,
      lines: (json['lines'] as List).map((e) => MetroLine.fromJson(e)).toList(),
      transfers: (json['transfers'] as List)
          .map((e) => MetroTransfer.fromJson(e))
          .toList(),
    );
  }
}

class MetroLine {
  final String id;
  final String name;
  final String? color;
  final List<String> stations;

  MetroLine({
    required this.id,
    required this.name,
    this.color,
    required this.stations,
  });

  factory MetroLine.fromJson(Map<String, dynamic> json) {
    return MetroLine(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      stations: List<String>.from(json['stations']),
    );
  }
}

class MetroTransfer {
  final String station;
  final List<String> lines;

  MetroTransfer({required this.station, required this.lines});

  factory MetroTransfer.fromJson(Map<String, dynamic> json) {
    return MetroTransfer(
      station: json['station'] as String,
      lines: List<String>.from(json['lines']),
    );
  }
}
