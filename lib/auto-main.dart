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
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_observation_page.dart';

void main() {
  runApp(MyApp());
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
  Timer? _accTimer;
  Timer? _gpsTimer;
  Timer? _btTimer;
  List<double> _accelerometerValues = [0.0, 0.0, 0.0];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    startAccelerometer();
    startBackgroundTasks();
  }

  void startAccelerometer() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = [event.x, event.y, event.z];
      });
    });
  }

  void startBackgroundTasks() {
    _accTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      await collectAndSendACCData();
    });
    // 5分钟
    _gpsTimer = Timer.periodic(Duration(seconds: 12), (timer) async {
      await collectAndSendGPSData();
    });
    // 五分钟
    _btTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await collectAndSendBluetoothData();
    });
  }

  @override
  void dispose() {
    _accTimer?.cancel();
    _gpsTimer?.cancel();
    _btTimer?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Future<void> collectAndSendData() async {
    String deviceInfo = await getDeviceInfo();
    await collectAndSendBluetoothData(deviceInfo);
    await collectAndSendGPSData(deviceInfo);
    await collectAndSendACCData(deviceInfo);
  }

  Future<String> getDeviceInfo() async {
    String deviceInfo = '';
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
    return deviceInfo;
  }

  Future<void> collectAndSendBluetoothData([String? deviceInfo]) async {
    deviceInfo ??= await getDeviceInfo();
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    List<ScanResult> scanResults = [];
    FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
    });

    await Future.delayed(Duration(seconds: 4)); // 等待扫描完成

    List<String> deviceNames = scanResults.map((result) {
      return result.device.remoteId.toString();
    }).toList();
    String devicesData = deviceNames.join(',');

    Map<String, dynamic> data = {
      'connection_device': devicesData,
      'device': deviceInfo,
    };

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateBT/'),
      body: data,
    );
    if (response.statusCode == 200) {
      print('Bluetooth data sent successfully');
    } else {
      print('Failed to send Bluetooth data. Error: ${response.reasonPhrase}');
    }
  }

  Future<void> collectAndSendGPSData([String? deviceInfo]) async {
    deviceInfo ??= await getDeviceInfo();
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    String latitude = position.latitude.toString();
    String longitude = position.longitude.toString();

    Map<String, dynamic> data = {
      'longitude': longitude,
      'device': deviceInfo,
      'latitude': latitude,
    };

    var response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateLocation/'),
      body: data,
    );
    if (response.statusCode == 200) {
      print('GPS data sent successfully');
    } else {
      print('Failed to send GPS data. Error: ${response.reasonPhrase}');
    }
  }

  Future<void> collectAndSendACCData([String? deviceInfo]) async {
    deviceInfo ??= await getDeviceInfo();
    Map<String, dynamic> data = {
      'acc_x': '${_accelerometerValues[0]}',
      'acc_y': '${_accelerometerValues[1]}',
      'acc_z': '${_accelerometerValues[2]}',
      'device': deviceInfo,
    };

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateAcc/'),
      body: data,
    );
    if (response.statusCode == 200) {
      print('Accelerometer data sent successfully');
    } else {
      print('Failed to send accelerometer data. Error: ${response.reasonPhrase}');
    }
  }

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
