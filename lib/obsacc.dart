import 'package:flutter/material.dart';
import 'package:flutter_charts/flutter_charts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'data_observation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

Future<void> fetchAndDisplayACCData(List<List<double>> dataPoints, List<String> dt) async {
  String accessToken = await getAccessToken();
  var url = Uri.parse('http://gps.primedigitaltech.com:8000/api/getACCdata/');
  try {
    var response = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    List<double> listx = [];
    List<double> listy = [];
    List<double> listz = [];

    if (response.statusCode == 200) {
      var jsonData = jsonDecode(response.body);
      var accelerometers = jsonData['accelerometers'];
      for (var i = 0; i < 100; i++) {
        var index = accelerometers.length - 1 - i;
        if (index < 0) break; // 确保索引不会超出数组范围
        var accelerometer = accelerometers[index];
        var x = accelerometer['acc_x'];
        var y = accelerometer['acc_y'];
        var z = accelerometer['acc_z'];
        listx.add(x);
        listy.add(y);
        listz.add(z);
        dt.add(accelerometer['timestamp'].substring(11, 19)); // 截断时间戳，只保留时分秒
      }
      dataPoints.add(listx);
      dataPoints.add(listy);
      dataPoints.add(listz);
    } else {
      print('Failed to load ACC data: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching ACC data: $e');
  }
}

Future<List<dynamic>> fetchACCData() async {
  List<List<double>> loader = [];
  List<String> timestamp = [];
  await fetchAndDisplayACCData(loader, timestamp);
  return [loader, timestamp];
}

Widget chartToRun(List<List<double>> dataPoints, List<String> dt) {
  ChartOptions chartOptions = const ChartOptions();

  ChartData chartData = ChartData(
    dataRows: dataPoints,
    xUserLabels: dt,
    dataRowsLegends: const ['X', 'Y', 'Z'],
    chartOptions: chartOptions,
  );
  LabelLayoutStrategy? xContainerLabelLayoutStrategy;
  var lineChartContainer = LineChartTopContainer(
    chartData: chartData,
    xContainerLabelLayoutStrategy: xContainerLabelLayoutStrategy,
  );
  var lineChart = LineChart(
    painter: LineChartPainter(
      lineChartContainer: lineChartContainer,
    ),
  );
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Container(
      width: dataPoints[0].length * 20, // 根据数据点数量调整宽度
      height: 400,
      child: lineChart,
    ),
  );
}

class AccObservationPage extends StatelessWidget {
  const AccObservationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acceleration:',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Acceleration:'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<List<dynamic>> futureData;

  @override
  void initState() {
    super.initState();
    futureData = fetchACCData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            const Text('Acceleration:'),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: futureData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (snapshot.hasData) {
                    List<List<double>> dataPoints = snapshot.data![0];
                    List<String> timestamp = snapshot.data![1];
                    return chartToRun(dataPoints, timestamp);
                  } else {
                    return const Text('No data available');
                  }
                },
              ),
            ),
            const Text('Acceleration: information used to calculate user status'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 返回到上一级页面
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DataObservationPage()),
          );
        },
        tooltip: '返回',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
