import 'package:flutter/material.dart';
import 'obsacc.dart';
import 'obsbt.dart';
import 'obsmap.dart';

void main() {
  runApp(MaterialApp(
    home: DataObservationPage(),
  ));
}

class DataObservationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Observation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                _navigateToGpsObservationPage(context); // 导航到 GPS 数据观测页面
              },
              child: Text('GPS Data Observation'),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateToBtObservationPage(context); // 导航到 BT 数据观测页面
              },
              child: Text('BT Data Observation'),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateToAccObservationPage(context); // 导航到 ACC 数据观测页面
              },
              child: Text('ACC Data Observation'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 返回到上一级页面
          Navigator.pop(context);
        },
        tooltip: '返回',
        child: Icon(Icons.arrow_back),
      ),
    );
  }

  // 导航到 GPS 数据观测页面
  void _navigateToGpsObservationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GpsObservationPage()),
    );
    // 返回后的操作，可以在这里处理
  }

  // 导航到 BT 数据观测页面
  void _navigateToBtObservationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BtObservationPage()),
    );
    // 返回后的操作，可以在这里处理
  }

  // 导航到 ACC 数据观测页面
  void _navigateToAccObservationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AccObservationPage()),
    );
    // 返回后的操作，可以在这里处理
  }
}
