import json
import math
from pathlib import Path


TARGET_CITIES = [
    ("shanghai", "上海"),
    ("hangzhou", "杭州"),
    ("beijing", "北京"),
    ("chongqing", "重庆"),
    ("guangzhou", "广州"),
    ("shenzhen", "深圳"),
    ("chengdu", "成都"),
    ("wuhan", "武汉"),
    ("xian", "西安"),
    ("nanjing", "南京"),
    ("suzhou", "苏州"),
    ("tianjin", "天津"),
    ("changsha", "长沙"),
    ("fuzhou", "福州"),
    ("xiamen", "厦门"),
    ("haerbin", "哈尔滨"),
]


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dedup_keep_order(items):
    seen = set()
    result = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def normalize_color(color: str | None):
    if not color:
        return None
    c = color.strip().lstrip("#")
    return f"#{c.upper()}" if c else None


def distance_sq(a, b):
    dx = a[0] - b[0]
    dy = a[1] - b[1]
    return dx * dx + dy * dy


def nearest_vertex_index(polyline, point):
    best_idx = -1
    best_dist = float("inf")
    for i, p in enumerate(polyline):
        d = distance_sq(p, point)
        if d < best_dist:
            best_dist = d
            best_idx = i
    return best_idx, best_dist


def station_candidates_by_bbox(stations, bbox, threshold):
    min_x, min_y, max_x, max_y = bbox
    expanded = (
        min_x - threshold,
        min_y - threshold,
        max_x + threshold,
        max_y + threshold,
    )
    result = []
    for station in stations:
        x, y = station["coord"]
        if expanded[0] <= x <= expanded[2] and expanded[1] <= y <= expanded[3]:
            result.append(station)
    return result


def build_line_defs(line_geo):
    line_defs = []
    for feature in line_geo["features"]:
        prop = feature["properties"]
        coords = feature["geometry"]["coordinates"]
        xs = [c[0] for c in coords]
        ys = [c[1] for c in coords]
        line_defs.append(
            {
                "id": prop.get("ls") or prop.get("short") or prop.get("name"),
                "name": prop.get("short") or prop.get("name") or prop.get("ls"),
                "color": normalize_color(prop.get("color")),
                "coords": coords,
                "bbox": (min(xs), min(ys), max(xs), max(ys)),
            }
        )
    return line_defs


def build_city(data_dir: Path, city_file_name: str, city_name: str):
    line_file = data_dir / f"{city_file_name}-line.json"
    station_file = data_dir / f"{city_file_name}-station.json"
    line_geo = load_json(line_file)
    station_geo = load_json(station_file)

    stations = []
    for feature in station_geo["features"]:
        name = (feature["properties"].get("name") or "").strip()
        if not name:
            continue
        coord = feature["geometry"]["coordinates"]
        stations.append(
            {
                "name": name,
                "coord": coord,
                "default_line": feature["properties"].get("ls"),
            }
        )
    station_by_name = {}
    for s in stations:
        station_by_name[s["name"]] = s

    line_defs = build_line_defs(line_geo)
    threshold = 0.00028
    line_to_stations = {line["id"]: [] for line in line_defs}
    station_to_lines = {s["name"]: set() for s in stations}

    for line in line_defs:
        candidates = station_candidates_by_bbox(stations, line["bbox"], threshold)
        for station in candidates:
            nearest_idx, nearest_dist = nearest_vertex_index(line["coords"], station["coord"])
            if nearest_idx < 0:
                continue
            if nearest_dist <= threshold * threshold:
                line_to_stations[line["id"]].append(
                    (nearest_idx, nearest_dist, station["name"])
                )
                station_to_lines[station["name"]].add(line["id"])

    for station in stations:
        if station_to_lines[station["name"]]:
            continue
        if not station["default_line"]:
            continue
        line_to_stations.setdefault(station["default_line"], []).append(
            (math.inf, 0.0, station["name"])
        )
        station_to_lines[station["name"]].add(station["default_line"])

    lines = []
    for line in line_defs:
        entries = line_to_stations.get(line["id"], [])
        entries.sort(key=lambda x: (x[0], x[1], x[2]))
        ordered_stations = dedup_keep_order([x[2] for x in entries])
        if ordered_stations:
            lines.append(
                {
                    "id": line["id"],
                    "name": line["name"],
                    "color": line["color"],
                    "stations": ordered_stations,
                }
            )

    for line in lines:
        for station in line["stations"]:
            station_to_lines.setdefault(station, set()).add(line["id"])

    transfers = []
    for station, line_ids in station_to_lines.items():
        if len(line_ids) >= 2:
            transfers.append({"station": station, "lines": sorted(line_ids)})

    transfers.sort(key=lambda x: x["station"])
    lines.sort(key=lambda x: x["name"])

    # Extract station coordinates
    station_coords = {}
    for name, s in station_by_name.items():
        # GeoJSON is [lon, lat], but usually apps use [lat, lon] or handle it specifically.
        # Let's keep it as [lon, lat] and handle it in Dart if needed, or swap here.
        # OpenMeteo needs latitude, longitude. So let's swap to [lat, lon] to be safe/standard for app usage?
        # Actually standard GeoJSON is [lon, lat]. Let's stick to [lon, lat] but document it.
        # Wait, the user wants accurate data.
        # Let's verify what OpenMeteo expects: latitude, longitude.
        # So I will store as {"name": [lat, lon]} to avoid confusion in Dart.
        lon, lat = s["coord"]
        station_coords[name] = [lat, lon]

    return {
        "city": city_name,
        "lines": lines,
        "transfers": transfers,
        "stations_geo": station_coords,
    }


def main():
    project_root = Path(__file__).resolve().parents[1]
    data_dir = project_root / ".tmp_subway_data" / "data"
    output_path = project_root / "assets" / "metro_data.json"

    cities = [build_city(data_dir, file_name, cn_name) for file_name, cn_name in TARGET_CITIES]
    output = {"cities": cities}
    output_path.write_text(
        json.dumps(output, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
