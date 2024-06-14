import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'bt.dart';
import 'gps.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeBackgroundTask(); // 初始化后台任务
  runApp(MyApp());
}

void initializeBackgroundTask() async {
  await FlutterBackground.initialize();
  startBackgroundTask();
}

void startBackgroundTask() async {
  await FlutterBackground.enableBackgroundExecution();
  await FlutterBackground.executeTask((taskId) async {
    // 在后台任务中执行收集蓝牙和GPS信息并传输到服务器的逻辑
    await collectAndSendData();
    // 每隔15秒执行一次
    await Future.delayed(Duration(seconds: 15));
  });
}

Future<void> collectAndSendData() async {
  await collectAndSendBluetoothData();
  await collectAndSendGPSData();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BluetoothScreen()),
                );
              },
              child: Text('Go to Bluetooth Page'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GpsPage()),
                );
              },
              child: Text('Go to GPS Page'),
            ),
          ],
        ),
      ),
    );
  }
}
