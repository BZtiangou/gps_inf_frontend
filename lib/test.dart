import 'package:flutter/material.dart';
import 'register.dart';  
import 'bt.dart';            
import 'gps.dart';
import 'login.dart';           
import 'accl.dart';          
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:device_info/device_info.dart';
import 'package:http/http.dart' as http;
import 'dart:io'; 
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(MyApp());
  void startBackgroundTask() {
  Timer.periodic(Duration(seconds: 15), (timer) async {
    await collectAndSendData();
  });
}
}

Future<void> collectAndSendData() async {
  String deviceInfo = '';
  // 获取手机设备信息
  try {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      deviceInfo = 'Device: ${androidInfo.brand} ${androidInfo.model}\nOS Version: ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      deviceInfo = 'Device: ${iosInfo.name} ${iosInfo.model}\nOS Version: ${iosInfo.systemVersion}';
    }
  } catch (e) {
    deviceInfo = 'Error fetching device info: $e';
  }
  await collectAndSendBluetoothData(deviceInfo);
  await collectAndSendGPSData(deviceInfo);
  await collectAndSendACCData(deviceInfo);
}

Future<void> collectAndSendBluetoothData(String deviceInfo) async {
    // 实现收集和发送蓝牙数据的逻辑
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    List<ScanResult> scanResults = [];
    FlutterBluePlus.scanResults.listen((results) {
        scanResults = results;
    });
    List<String> deviceNames = scanResults.map((result) {
      return result.device.name.isNotEmpty ? result.device.name : 'Unknown Device';
    }).toList();
    String devicesData = deviceNames.join(',');

    Map<String, dynamic> data = {
      'connection_device': devicesData.substring(0,150),
      'device': deviceInfo,
    };

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateBT/'),
      body: data,
    );
    print('Data sent successfully');
  }

Future<void> collectAndSendGPSData(String deviceInfo) async {
  // 实现收集和发送ACC数据的逻辑
    String longitude = '';
    String latitude = '';
    String deviceInfo = '';
    Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high);
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
        Map<String, dynamic> data = {
      'longitude': longitude,
      'device': deviceInfo,
      'latitude': latitude,
    };
    var response = await http.post(
        Uri.parse('http://gps.primedigitaltech.com:8000/api/updateLocation/'),
        body: data,
      );
    print('Data sent successfully');
}

Future<void> collectAndSendACCData(String deviceInfo) async {
  // 实现收集和发送GPS数据的逻辑
    String longitude = '';
    String latitude = '';
    String deviceInfo = '';
    Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high);
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
        Map<String, dynamic> data = {
      'longitude': longitude,
      'device': deviceInfo,
      'latitude': latitude,
    };
    var response = await http.post(
        Uri.parse('http://gps.primedigitaltech.com:8000/api/updateLocation/'),
        body: data,
      );
    print('Data sent successfully');
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

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Text('Go to Register Page'),
            ),
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
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AcclPage()),
                );
              },
              child: Text('Go to ACC Page'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Text('Go to Login Page'),
            ),
          ],
        ),
      ),
    );
  }
}
