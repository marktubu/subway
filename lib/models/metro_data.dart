class MetroCatalog {
  final List<MetroData> cities;

  MetroCatalog({required this.cities});

  factory MetroCatalog.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('cities')) {
      return MetroCatalog(
        cities: (json['cities'] as List)
            .map((e) => MetroData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return MetroCatalog(cities: [MetroData.fromJson(json)]);
  }
}

class MetroData {
  final String city;
  final List<MetroLine> lines;
  final List<MetroTransfer> transfers;
  final Map<String, List<double>> stationsGeo;

  MetroData({
    required this.city,
    required this.lines,
    required this.transfers,
    required this.stationsGeo,
  });

  factory MetroData.fromJson(Map<String, dynamic> json) {
    Map<String, List<double>> stationsGeo = {};
    if (json.containsKey('stations_geo')) {
      final geoMap = json['stations_geo'] as Map<String, dynamic>;
      geoMap.forEach((key, value) {
        if (value is List && value.length == 2) {
          stationsGeo[key] = [
            (value[0] as num).toDouble(),
            (value[1] as num).toDouble(),
          ];
        }
      });
    }

    return MetroData(
      city: json['city'] as String,
      lines:
          (json['lines'] as List).map((e) => MetroLine.fromJson(e)).toList(),
      transfers:
          (json['transfers'] as List)
              .map((e) => MetroTransfer.fromJson(e))
              .toList(),
      stationsGeo: stationsGeo,
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
