import 'package:flutter/material.dart';
import 'package:device_info/device_info.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'data_observation_page.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

Timer? _accTimer;
Timer? _gpsTimer;
Timer? _btTimer;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<double> _accelerometerValues = [0.0, 0.0, 0.0];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  String _deviceInfo = 'Fetching device info...';

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
    _startListeningToAccelerometer();
  }

  void _startListeningToAccelerometer() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = [event.x, event.y, event.z];
      });
    });
  }

  void startBackgroundTasks(int gpsFrequency, int accFrequency, int btFrequency) {
    _accTimer = Timer.periodic(Duration(seconds: accFrequency), (timer) async {
      await collectAndSendACCData();
    });
    _gpsTimer = Timer.periodic(Duration(seconds: gpsFrequency), (timer) async {
      await collectAndSendGPSData();
    });
    _btTimer = Timer.periodic(Duration(minutes: btFrequency), (timer) async {
      await collectAndSendBluetoothData();
    });
  }

  Future<void> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      setState(() {
        _deviceInfo = 'Device: ${androidInfo.brand} ${androidInfo.model}, OS Version: ${androidInfo.version.release}';
      });
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      setState(() {
        _deviceInfo = 'Device: ${iosInfo.name} ${iosInfo.model}, OS Version: ${iosInfo.systemVersion}';
      });
    } else {
      setState(() {
        _deviceInfo = 'Error fetching device info';
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      String username = _usernameController.text;
      String password = _passwordController.text;

      Map<String, String> data = {
        'username': username,
        'password': password,
      };

      try {
        final response = await http.post(
          Uri.parse('http://gps.primedigitaltech.com:8000/api/login/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(data),
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> responseData = json.decode(response.body);
          String accessToken = responseData['access'];

          // 存储access令牌到本地存储
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('username', username);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login successful')),
          );

          // 获取实验信息
          _fetchExperimentInfo(accessToken);

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DataObservationPage()),
          );
        } else {
          Map<String, dynamic> responseData = json.decode(response.body);
          String message = responseData['message'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: $message')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登陆失败! 请检查您的账号和密码')),
        );
      }
    }
  }

  Future<void> _fetchExperimentInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('http://gps.primedigitaltech.com:8000/exp/myExp/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> experimentData = json.decode(response.body);
        if (experimentData.isNotEmpty) {
          Map<String, dynamic> experiment = experimentData[0];
          int gpsFrequency = experiment['gps_frequency'];
          int accFrequency = experiment['acc_frequency'];
          int btFrequency = experiment['bt_frequency'];
          // 启动后台任务
          startBackgroundTasks(gpsFrequency, accFrequency, btFrequency);
          // 根据频率值自动化上传传感器信息
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No experiment data found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch experiment data: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> collectAndSendACCData([String? deviceInfo]) async {
    deviceInfo ??= _deviceInfo;
    Map<String, dynamic> data = {
      'acc_x': '${_accelerometerValues[0]}',
      'acc_y': '${_accelerometerValues[1]}',
      'acc_z': '${_accelerometerValues[2]}',
      'device': deviceInfo,
    };

    String accessToken = await _getAccessToken(); // Get access token from SharedPreferences

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

  Future<void> collectAndSendGPSData([String? deviceInfo]) async {
  bool hasLocationPermission = await requestLocationPermission();
  if (!hasLocationPermission) {
    print('定位权限申请不通过');
    return;
  }

  AMapFlutterLocation locationPlugin = AMapFlutterLocation();
  AMapFlutterLocation.updatePrivacyShow(true, true);
  AMapFlutterLocation.updatePrivacyAgree(true);
  AMapFlutterLocation.setApiKey("d33074d34e5524ed087ce820363a1779", "IOS Api Key");

  bool isConnected = true;
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

  deviceInfo ??= _deviceInfo;

  Map<String, dynamic> data = {
    'longitude': longitude,
    'device': deviceInfo,
    'latitude': latitude,
    'accuracy': accuracy,
  };

  String accessToken = await _getAccessToken();

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

    Map<String, dynamic> responseData = json.decode(response.body);
    int flag = responseData['flag'];

    if (flag == 1) {
      double longitudeMin = responseData['longitude_min'];
      double longitudeMax = responseData['longitude_max'];
      double latitudeMin = responseData['latitude_min'];
      double latitudeMax = responseData['latitude_max'];

      // 保存坐标范围到本地存储
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('longitude_min', longitudeMin);
      await prefs.setDouble('longitude_max', longitudeMax);
      await prefs.setDouble('latitude_min', latitudeMin);
      await prefs.setDouble('latitude_max', latitudeMax);
      
      print('Coordinate range saved to storage.');
    }
  } else {
    print('Failed to send GPS data. Error: ${response.reasonPhrase}');
  }
}


  Future<void> collectAndSendBluetoothData([String? deviceInfo]) async {
    deviceInfo ??= _deviceInfo;
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));
    List<ScanResult> scanResults = [];
    FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
    });

    await Future.delayed(Duration(seconds: 4));

    String bluetoothData = scanResults.map((result) => result.device.id.toString()).join(';');
    String accessToken = await _getAccessToken();
    var response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/api/updateBT/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'connection_device': bluetoothData, 'device': deviceInfo}),
    );
    if (response.statusCode == 200) {
      print('Bluetooth data sent successfully');
    } 
  }

  Future<bool> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    return status.isGranted;
  }

  Future<String> _getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[100]!,
              Colors.blue[200]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '欢迎登陆',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 30),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '账号',
                    hintText: '输入账号/手机号',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入您的账号';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入您的密码';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(_deviceInfo),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    child: Text('登录'),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RegisterPage()),
                        );
                      },
                      child: Text('注册账号'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ForgotPasswordStep1()),  // 跳转到忘记密码页面
                        );
                      },
                      child: Text('忘记密码？'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _accTimer?.cancel();
    _gpsTimer?.cancel();
    _btTimer?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }
}

// 取消计时器的函数
void cancelTimers() {
  _accTimer?.cancel();
  _gpsTimer?.cancel();
  _btTimer?.cancel();
}

void main() {
  runApp(MaterialApp(
    home: LoginPage(),
  ));
}
