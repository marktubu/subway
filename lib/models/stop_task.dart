enum ActionType { transfer, exit }

class StopTask {
  final String name;
  final ActionType action;
  final String? fromLine;
  final String? toLine;

  StopTask({
    required this.name,
    required this.action,
    this.fromLine,
    this.toLine,
  });

  factory StopTask.transfer({
    required String name,
    required String fromLine,
    required String toLine,
  }) {
    return StopTask(
      name: name,
      action: ActionType.transfer,
      fromLine: fromLine,
      toLine: toLine,
    );
  }

  factory StopTask.exit({required String name}) {
    return StopTask(name: name, action: ActionType.exit);
  }
}
