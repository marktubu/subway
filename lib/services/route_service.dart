import 'package:collection/collection.dart';
import '../models/metro_data.dart';
import '../models/stop_task.dart';

class Node {
  final String station;
  final String lineId;

  Node(this.station, this.lineId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          runtimeType == other.runtimeType &&
          station == other.station &&
          lineId == other.lineId;

  @override
  int get hashCode => station.hashCode ^ lineId.hashCode;

  @override
  String toString() => '${station}_$lineId';
}

class Edge {
  final Node to;
  final int cost;

  Edge(this.to, this.cost);
}

class RouteService {
  final MetroData metroData;
  late final Map<Node, List<Edge>> graph;
  late final Map<String, MetroLine> lineMap;
  late final Map<String, Set<String>> transferMap;

  RouteService(this.metroData) {
    _buildGraph();
  }

  void _buildGraph() {
    graph = {};
    lineMap = {for (var line in metroData.lines) line.id: line};
    transferMap = {};

    // Add intra-line edges
    for (var line in metroData.lines) {
      for (int i = 0; i < line.stations.length; i++) {
        var u = Node(line.stations[i], line.id);
        if (!graph.containsKey(u)) graph[u] = [];

        if (i > 0) {
          var v = Node(line.stations[i - 1], line.id);
          graph[u]!.add(Edge(v, 1));
        }
        if (i < line.stations.length - 1) {
          var v = Node(line.stations[i + 1], line.id);
          graph[u]!.add(Edge(v, 1));
        }
      }
    }

    // Add inter-line (transfer) edges
    for (var transfer in metroData.transfers) {
      String station = transfer.station;
      List<String> lines = transfer.lines;
      transferMap[station] = lines.toSet();

      for (int i = 0; i < lines.length; i++) {
        for (int j = i + 1; j < lines.length; j++) {
          var u = Node(station, lines[i]);
          var v = Node(station, lines[j]);

          if (!graph.containsKey(u)) graph[u] = [];
          if (!graph.containsKey(v)) graph[v] = [];

          // cost = 3 for transfer
          graph[u]!.add(Edge(v, 3));
          graph[v]!.add(Edge(u, 3));
        }
      }
    }
  }

  List<StopTask>? planRoute(String startStation, String endStation) {
    if (startStation == endStation) return [];

    // Find all nodes for start and end
    List<Node> startNodes = graph.keys
        .where((n) => n.station == startStation)
        .toList();
    List<Node> endNodes = graph.keys
        .where((n) => n.station == endStation)
        .toList();

    if (startNodes.isEmpty || endNodes.isEmpty) return null;

    List<Node>? bestPath;
    int minCost = -1;

    for (var startNode in startNodes) {
      for (var endNode in endNodes) {
        var pathInfo = _dijkstra(startNode, endNode);
        if (pathInfo != null) {
          if (!_isPathTransferValid(pathInfo.path)) {
            continue;
          }
          if (minCost == -1 || pathInfo.cost < minCost) {
            minCost = pathInfo.cost;
            bestPath = pathInfo.path;
          }
        }
      }
    }

    if (bestPath == null) return null;

    return _pathToTasks(bestPath);
  }

  List<StopTask>? planMultiRoute(List<String> stations) {
    if (stations.length < 2) return null;

    List<Node> fullPath = [];

    for (int i = 0; i < stations.length - 1; i++) {
      List<Node> startNodes = graph.keys
          .where((n) => n.station == stations[i])
          .toList();
      List<Node> endNodes = graph.keys
          .where((n) => n.station == stations[i + 1])
          .toList();

      if (startNodes.isEmpty || endNodes.isEmpty) return null;

      List<Node>? bestSegment;
      int minCost = -1;

      // If we already have a previous segment, we should force the start node to be the same line
      // as the end of the previous segment, to avoid unnecessary transfer penalties at the waypoint itself.
      if (fullPath.isNotEmpty) {
        startNodes = [fullPath.last];
      }

      for (var startNode in startNodes) {
        for (var endNode in endNodes) {
          var pathInfo = _dijkstra(startNode, endNode);
          if (pathInfo != null) {
            if (!_isPathTransferValid(pathInfo.path)) {
              continue;
            }
            if (minCost == -1 || pathInfo.cost < minCost) {
              minCost = pathInfo.cost;
              bestSegment = pathInfo.path;
            }
          }
        }
      }

      if (bestSegment == null) return null;

      if (fullPath.isEmpty) {
        fullPath.addAll(bestSegment);
      } else {
        // Skip the first node as it's the same as fullPath.last
        fullPath.addAll(bestSegment.skip(1));
      }
    }

    return _pathToTasks(fullPath);
  }

  _PathResult? _dijkstra(Node start, Node end) {
    var distances = <Node, int>{};
    var previous = <Node, Node>{};
    var pq = PriorityQueue<_QueueItem>(
      (a, b) => a.distance.compareTo(b.distance),
    );

    for (var node in graph.keys) {
      distances[node] = 1000000;
    }
    distances[start] = 0;
    pq.add(_QueueItem(start, 0));

    while (pq.isNotEmpty) {
      var current = pq.removeFirst();
      var u = current.node;

      if (u == end) break;
      if (current.distance > distances[u]!) continue;

      for (var edge in graph[u] ?? <Edge>[]) {
        var v = edge.to;
        var alt = distances[u]! + edge.cost;
        if (alt < distances[v]!) {
          distances[v] = alt;
          previous[v] = u;
          pq.add(_QueueItem(v, alt));
        }
      }
    }

    if (distances[end] == 1000000) return null;

    List<Node> path = [];
    Node? curr = end;
    while (curr != null) {
      path.insert(0, curr);
      curr = previous[curr];
    }

    return _PathResult(path, distances[end]!);
  }

  List<StopTask> _pathToTasks(List<Node> path) {
    List<StopTask> tasks = [];
    if (path.isEmpty) return tasks;

    String currentLine = path.first.lineId;

    for (int i = 1; i < path.length; i++) {
      var node = path[i];
      if (node.lineId != currentLine && node.station == path[i - 1].station) {
        tasks.add(
          StopTask.transfer(
            name: node.station,
            fromLine: lineMap[currentLine]?.name ?? currentLine,
            toLine: lineMap[node.lineId]?.name ?? node.lineId,
          ),
        );
        currentLine = node.lineId;
      }
    }

    tasks.add(StopTask.exit(name: path.last.station));
    return tasks;
  }

  bool _isPathTransferValid(List<Node> path) {
    for (int i = 1; i < path.length; i++) {
      final prev = path[i - 1];
      final curr = path[i];
      if (prev.station != curr.station || prev.lineId == curr.lineId) {
        continue;
      }
      final transferLines = transferMap[prev.station];
      if (transferLines == null) {
        return false;
      }
      if (!transferLines.contains(prev.lineId) ||
          !transferLines.contains(curr.lineId)) {
        return false;
      }
    }
    return true;
  }
}

class _QueueItem {
  final Node node;
  final int distance;

  _QueueItem(this.node, this.distance);
}

class _PathResult {
  final List<Node> path;
  final int cost;

  _PathResult(this.path, this.cost);
}
