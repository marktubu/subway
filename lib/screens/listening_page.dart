import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../models/stop_task.dart';
import '../services/speech_service.dart';

class ListeningPage extends StatefulWidget {
  final List<StopTask> tasks;
  final List<String> originalStations;

  const ListeningPage({
    super.key,
    required this.tasks,
    required this.originalStations,
  });

  @override
  ListeningPageState createState() => ListeningPageState();
}

class ListeningPageState extends State<ListeningPage> {
  int _currentTaskIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListeningForCurrentTask();
    });
  }

  void _startListeningForCurrentTask() {
    if (_currentTaskIndex >= widget.tasks.length) return;

    final speechService = Provider.of<SpeechService>(context, listen: false);
    final task = widget.tasks[_currentTaskIndex];

    speechService.startListeningFor(task.name, (matchedStation) {
      _onTargetReached(task);
    });
  }

  void _onTargetReached(StopTask task) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    speechService.stopListening();

    // Trigger vibration
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      if (task.action == ActionType.exit) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000, 500, 1000]);
        SystemSound.play(SystemSoundType.alert);
      } else {
        Vibration.vibrate(pattern: [500, 500]);
      }
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Scaffold(
          backgroundColor: task.action == ActionType.exit
              ? Colors.red
              : Colors.blue,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  task.action == ActionType.exit
                      ? Icons.exit_to_app
                      : Icons.transfer_within_a_station,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  task.action == ActionType.exit
                      ? '终点站 ${task.name} 到了\n请准备下车！'
                      : '前方 ${task.name} 站\n请换乘 ${task.toLine}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    task.action == ActionType.exit ? '结束行程' : '已换乘，继续监听',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (task.action == ActionType.exit) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _currentTaskIndex++;
      });
      _startListeningForCurrentTask();
    }
  }

  void _manualNext() {
    if (_currentTaskIndex >= widget.tasks.length) {
      return;
    }
    final currentTask = widget.tasks[_currentTaskIndex];
    if (currentTask.action == ActionType.exit) {
      _onTargetReached(currentTask);
      return;
    }
    Provider.of<SpeechService>(context, listen: false).stopListening();
    setState(() {
      _currentTaskIndex++;
    });
    _startListeningForCurrentTask();
  }

  @override
  void dispose() {
    Provider.of<SpeechService>(context, listen: false).stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行程监听中'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('结束', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildRouteNodes()),
            ),
          ),

          Expanded(
            child: Center(
              child: Consumer<SpeechService>(
                builder: (context, speech, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentTaskIndex < widget.tasks.length)
                        Text(
                          '正在等待: ${widget.tasks[_currentTaskIndex].name}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        '语音识别内容(调试):',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          speech.lastRecognizedWords.isEmpty
                              ? '(等待语音输入...)'
                              : speech.lastRecognizedWords,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (speech.isListening)
                        const CircularProgressIndicator()
                      else
                        const Text(
                          '监听已暂停',
                          style: TextStyle(color: Colors.red),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _manualNext,
                child: const Text('手动跳过当前站', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRouteNodes() {
    List<Widget> widgets = [];

    widgets.add(
      _buildNode(widget.originalStations.first, _currentTaskIndex == 0),
    );

    for (int i = 0; i < widget.tasks.length; i++) {
      widgets.add(const Icon(Icons.arrow_right, color: Colors.grey));
      bool isCurrent = i == _currentTaskIndex;
      widgets.add(_buildNode(widget.tasks[i].name, isCurrent));
    }

    return widgets;
  }

  Widget _buildNode(String name, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isCurrent ? Colors.white : Colors.black,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
