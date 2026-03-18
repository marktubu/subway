import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/app_state.dart';
import 'listening_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _startStation;
  String? _endStation;
  String? _selectedCity;
  List<String> _multiStations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedRoute();
    });
  }

  void _loadSavedRoute() {
    final appState = Provider.of<AppState>(context, listen: false);
    final prefs = appState.prefs;

    setState(() {
      _startStation = prefs.getString('startStation');
      _endStation = prefs.getString('endStation');
      final savedMulti = prefs.getStringList('multiStations');
      if (savedMulti != null) {
        _multiStations = List.from(savedMulti);
      }

      // Validation: if saved stations are not in the current city, clear them
      final metroData = appState.currentMetroData;
      Set<String> allStations = {};
      for (var line in metroData.lines) {
        allStations.addAll(line.stations);
      }

      if (_startStation != null && !allStations.contains(_startStation)) {
        _startStation = null;
      }
      if (_endStation != null && !allStations.contains(_endStation)) {
        _endStation = null;
      }
      _multiStations.removeWhere((s) => !allStations.contains(s));
    });
  }

  void _saveRoute() {
    final prefs = Provider.of<AppState>(context, listen: false).prefs;
    if (_startStation != null) prefs.setString('startStation', _startStation!);
    if (_endStation != null) prefs.setString('endStation', _endStation!);
    prefs.setStringList('multiStations', _multiStations);
  }

  void _startRide() {
    final appState = Provider.of<AppState>(context, listen: false);
    final routeService = appState.routeService;
    List<String> routeInput = [];

    if (_tabController.index == 0) {
      if (_startStation == null || _endStation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择出发站和终点站')),
        );
        return;
      }
      routeInput = [_startStation!, _endStation!];
    } else {
      if (_multiStations.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少添加两个途经站')),
        );
        return;
      }
      routeInput = List.from(_multiStations);
    }

    _saveRoute();

    var tasks = routeService.planMultiRoute(routeInput);
    if (tasks == null || tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法找到可用路线，请检查站点')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ListeningPage(tasks: tasks, originalStations: routeInput),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final metroData = appState.currentMetroData;
    _selectedCity ??= appState.selectedCity;
    Set<String> allStations = {};
    for (var line in metroData.lines) {
      allStations.addAll(line.stations);
    }
    List<String> stationList = allStations.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('${metroData.city} 防过站'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '自动规划'),
            Tab(text: '手动多站点'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModeA(stationList, appState.cityNames),
          _buildModeB(stationList),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: _startRide,
          child: const Text('开始乘车'),
        ),
      ),
    );
  }

  Widget _buildModeA(List<String> stationList, List<String> cityNames) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          InputDecorator(
            decoration: const InputDecoration(labelText: '城市'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedCity,
                items: cityNames
                    .map(
                      (city) =>
                          DropdownMenuItem(value: city, child: Text(city)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) {
                    return;
                  }
                  Provider.of<AppState>(context, listen: false).selectCity(v);
                  setState(() {
                    _selectedCity = v;
                    _startStation = null;
                    _endStation = null;
                    _multiStations.clear();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(hintText: "搜索出发站"),
              ),
            ),
            items: (String filter, LoadProps? loadProps) async {
              return stationList.where((s) => s.contains(filter)).toList();
            },
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: "出发站",
                hintText: "请选择或搜索出发站",
              ),
            ),
            onChanged: (v) => setState(() => _startStation = v),
            selectedItem: _startStation,
          ),
          const SizedBox(height: 16),
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(hintText: "搜索终点站"),
              ),
            ),
            items: (String filter, LoadProps? loadProps) async {
              return stationList.where((s) => s.contains(filter)).toList();
            },
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: "终点站",
                hintText: "请选择或搜索终点站",
              ),
            ),
            onChanged: (v) => setState(() => _endStation = v),
            selectedItem: _endStation,
          ),
        ],
      ),
    );
  }

  Widget _buildModeB(List<String> stationList) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownSearch<String>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: "搜索途经站",
                      ),
                    ),
                  ),
                  items: (String filter, LoadProps? loadProps) async {
                    return stationList.where((s) => s.contains(filter)).toList();
                  },
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "添加站点",
                      hintText: "请选择或搜索站点",
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _multiStations.add(v));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _multiStations.removeAt(oldIndex);
                _multiStations.insert(newIndex, item);
              });
            },
            children: [
              for (int i = 0; i < _multiStations.length; i++)
                ListTile(
                  key: ValueKey('$_multiStations[$i]_$i'),
                  title: Text(_multiStations[i]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _multiStations.removeAt(i);
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
