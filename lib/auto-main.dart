import 'package:flutter/material.dart';
import 'register.dart';
import 'bt.dart';
import 'gps.dart';
import 'login.dart';
import 'accl.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info/device_info.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';

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
    _gpsTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await collectAndSendGPSData();
    });
    // 五分钟
    _btTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
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

  Future<String> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');
    if (accessToken == null) {
      throw Exception('Access token not found in SharedPreferences');
    }
    return accessToken;
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
    String accessToken = await getAccessToken(); // Get access token from SharedPreferences
    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateBT/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      print('Bluetooth data sent successfully');
    } else {
      print('Failed to send Bluetooth data. Error: ${response.reasonPhrase}');
    }
  }

  Future<void> collectAndSendGPSData([String? deviceInfo]) async {
  // 动态申请定位权限
  bool hasLocationPermission = await requestLocationPermission();
  if (!hasLocationPermission) {
    print('定位权限申请不通过');
    return;
  }

  // 设置高德地图定位参数
  AMapFlutterLocation locationPlugin = AMapFlutterLocation();
  AMapFlutterLocation.updatePrivacyShow(true, true);
  AMapFlutterLocation.updatePrivacyAgree(true);
  AMapFlutterLocation.setApiKey("d33074d34e5524ed087ce820363a1779", "IOS Api Key");

  bool isConnected = await checkInternetConnection();
  print("Network connected: $isConnected");

  AMapLocationOption locationOption = AMapLocationOption();
  locationOption.onceLocation = true;
  locationOption.needAddress = false;
  locationOption.locationMode = isConnected ? AMapLocationMode.Hight_Accuracy : AMapLocationMode.Device_Sensors;
  locationOption.desiredAccuracy = DesiredAccuracy.Best;
  locationOption.geoLanguage = GeoLanguage.DEFAULT;
  locationPlugin.setLocationOption(locationOption);

  Completer<Map<String, Object>> completer = Completer();
  locationPlugin.onLocationChanged().listen((Map<String, Object> result) {
    if (!completer.isCompleted) {
      completer.complete(result);
      locationPlugin.stopLocation();
    }
  });

  locationPlugin.startLocation();
  Map<String, Object> locationResult = await completer.future;

  double latitude = locationResult['latitude'] as double;
  double longitude = locationResult['longitude'] as double;
  double accuracy = locationResult['accuracy'] as double;

  // 获取设备信息
  deviceInfo ??= await getDeviceInfo();

  Map<String, dynamic> data = {
    'longitude': longitude,
    'device': deviceInfo,
    'latitude': latitude,
    'accuracy': accuracy,
  };

  // 获取 Access Token
  String accessToken = await getAccessToken();

  var response = await http.post(
    Uri.parse('http://gps.primedigitaltech.com:8000/api/updateLocation/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode(data),
  );
  if (response.statusCode == 200) {
    print('GPS data sent successfully');
  } else {
    print('Failed to send GPS data. Error: ${response.reasonPhrase}');
  }
}

/// 检查网络连接状态
Future<bool> checkInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

/// 动态申请定位权限
Future<bool> requestLocationPermission() async {
  var status = await Permission.location.status;
  if (status == PermissionStatus.granted) {
    return true;
  } else {
    status = await Permission.location.request();
    return status == PermissionStatus.granted;
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

    String accessToken = await getAccessToken(); // Get access token from SharedPreferences

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateAcc/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
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
