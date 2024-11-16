import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'data_observation_page.dart';
import 'register.dart';
import 'forgot_password.dart';
// import 'battery_optimization.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // 引入前台服务包
import 'MyTaskHandler.dart'; // 引入刚才创建的MyTaskHandler
// import 'package:android_intent_plus/android_intent.dart';

Timer? _accTimer;
Timer? _gyroTimer;
int bttime=15;
int gpstime=15;

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  List<double> _gyroscopeValues = [0.0, 0.0, 0.0];
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  List<double> _accelerometerValues = [0.0, 0.0, 0.0];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  String _deviceInfo = 'Fetching device info...';

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // 请求所有权限
    _initService(); // 初始化前台服务
    _getDeviceInfo();
    // openBatteryOptimizationSettings();
    _startListeningToAccelerometer();
    _startListeningToGyroscope(); // 启动陀螺仪监听
    // BatteryOptimization.requestIgnoreBatteryOptimizations();
  }

  // 请求所需的权限
  Future<void> _requestPermissions() async {
  final NotificationPermission notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    if (!await FlutterForegroundTask.canScheduleExactAlarms) {
      await FlutterForegroundTask.openAlarmsAndRemindersSettings();
    }
    }
      Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.sensors,
      Permission.storage,
    ].request();

    statuses.forEach((permission, status) {
    if (status != PermissionStatus.granted) {
      // 这里处理权限未被授予的情况，例如提示用户或者禁用某些功能
      print('权限 $permission 未被授予，状态：$status');
    } else {
      // 权限被授予，可以执行需要该权限的操作
      print('权限 $permission 已被授予');
    }
    });
  }

  void _startListeningToAccelerometer() {
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = [event.x, event.y, event.z];
      });
    });
  }

  void _startListeningToGyroscope() {
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues = [event.x, event.y, event.z];
      });
    });
  }
  
//   void openBatteryOptimizationSettings() {
//   const intent = AndroidIntent(
//     action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
//   );
//   intent.launch();
// }
  
  void startBackgroundTasks(
      int gpsFrequency, int accFrequency, int btFrequency, int gyroFrequency) {
    _accTimer = Timer.periodic(Duration(seconds: accFrequency), (timer) async {
      await collectAndSendACCData();
    });
    _gyroTimer =
        Timer.periodic(Duration(seconds: gyroFrequency), (timer) async {
      await collectAndSendGyroData();
    });
  }

  Future<void> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      setState(() {
        _deviceInfo =
            'Device: ${androidInfo.brand} ${androidInfo.model}, OS Version: ${androidInfo.version.release}';
      });
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      setState(() {
        _deviceInfo =
            'Device: ${iosInfo.name} ${iosInfo.model}, OS Version: ${iosInfo.systemVersion}';
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
          collectAndSendBluetoothData();
          collectAndSendGPSData();
          // 获取实验信息
          _fetchExperimentInfo(accessToken);
          _startService();

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

  Future<void> _initService() async {
    // 启动前台服务
    // notification唤醒
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service',
        channelDescription:
            'This notification appears when the service is running.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions:ForegroundTaskOptions(
        eventAction:ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true, // 防止CPU休眠
        allowWifiLock: true, // 防止WiFi休眠
      ),
    );
  }

  Future<ServiceRequestResult> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }
    return FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '移动感知正守护您的数据安全',
      notificationText: '点击返回，请不要结束进程',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'btn_hello', text: 'hello'),
      ],
      callback: startCallback,
    );
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
          int gyroFrequency = experiment['gyro_frequency'];
          // 启动后台任务
          bttime=btFrequency;
          gpstime=gpsFrequency;
          startBackgroundTasks(
              gpsFrequency, accFrequency, btFrequency, gyroFrequency);
          // 根据频率值自动化上传传感器信息
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No experiment data found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch experiment data: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<bool> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    return status.isGranted;
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
    AMapFlutterLocation.setApiKey(
        "d33074d34e5524ed087ce820363a1779", "IOS Api Key");

    // 检查网络连接状态
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult == ConnectivityResult.wifi ||
        connectivityResult == ConnectivityResult.mobile;

    AMapLocationOption locationOption = AMapLocationOption();
    locationOption.onceLocation = true;
    locationOption.needAddress = false;

    // 根据网络连接状态设置定位模式
    if (isConnected) {
      locationOption.locationMode = AMapLocationMode.Hight_Accuracy;
    } else {
      locationOption.locationMode = AMapLocationMode.Device_Sensors;
    }

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
      Uri.parse('http://gps.primedigitaltech.com:8000/sensor/updateLocation/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      print('GPS data sent successfully');

      Map<String, dynamic> responseData = json.decode(response.body);
      // 在这里处理响应数据
    } else {
      print('Failed to send GPS data. Error: ${response.reasonPhrase}');
    }
  }

Future<void> collectAndSendBluetoothData([String? deviceInfo]) async {
    deviceInfo ??= _deviceInfo; // 使用默认设备信息
    List<String> bluetoothDataList = [];
    Set<String> deviceSet = {}; // 用于去重
    if (await FlutterBluePlus.isSupported == false) {
    print("Bluetooth not supported by this device");
    return;
  }
  else {print('Bluetooth supported');}
var subscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
    print(state);
    if (state == BluetoothAdapterState.on) {
        print('Bluetooth is on');
    } else {
        print('bluetooth is off');
    }
});
if (Platform.isAndroid) {
    await FlutterBluePlus.turnOn();
}
// cancel to prevent duplicate listeners
subscription.cancel();
    final permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
      var subscription = FlutterBluePlus.onScanResults.listen((results) {
        if (results.isNotEmpty) {
          for (var result in results) {
            String deviceName = result.device.name.isNotEmpty ? result.device.name : 'undefined';
            String deviceId = result.device.id.toString();
            String deviceInfo = '$deviceName:$deviceId';

            if (!deviceSet.contains(deviceInfo)) {
              deviceSet.add(deviceInfo);
              bluetoothDataList.add(deviceInfo);
            }
          }
        }
    },
    onError: (e) => print(e),
);

// cleanup: cancel subscription when scanning stops
FlutterBluePlus.cancelWhenScanComplete(subscription);
await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;

await FlutterBluePlus.startScan(
  timeout: Duration(seconds:5),
  androidScanMode : AndroidScanMode.lowPower
  );

// wait for scanning to stop
await FlutterBluePlus.isScanning.where((val) => val == false).first;
    }

 String bluetoothData = bluetoothDataList.join(';');
    String accessToken = await _getAccessToken();
    print('蓝牙数据：$bluetoothData');
    var response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/sensor/updateBT/'), 
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'connection_device': bluetoothData}),
    );

    if (response.statusCode == 200) {
      print('Bluetooth data sent successfully');
    } else {
      print('Failed to send Bluetooth data: ${response.statusCode}');
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

    String accessToken =
        await _getAccessToken(); // Get access token from SharedPreferences

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/sensor/updateAcc/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print('Accelerometer data sent successfully');
    } else {
      print(
          'Failed to send accelerometer data. Error: ${response.reasonPhrase}');
    }
  }

  Future<void> collectAndSendGyroData([String? deviceInfo]) async {
    deviceInfo ??= _deviceInfo;
    Map<String, dynamic> data = {
      'x': '${_gyroscopeValues[0]}',
      'y': '${_gyroscopeValues[1]}',
      'z': '${_gyroscopeValues[2]}',
      'device': deviceInfo,
    };

    String accessToken =
        await _getAccessToken(); // Get access token from SharedPreferences

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/sensor/updateGyro/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print('Gyroscope data sent successfully');
    } else {
      print('Failed to send gyroscope data. Error: ${response.reasonPhrase}');
    }
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
                          MaterialPageRoute(
                              builder: (context) => RegisterPage()),
                        );
                      },
                      child: Text('注册账号'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ForgotPasswordStep1()), // 跳转到忘记密码页面
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
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel(); // 取消陀螺仪订阅
    super.dispose();
    // 停止前台服务
    FlutterForegroundTask.stopService();
  }
}

// 取消计时器的函数
void cancelTimers() {
  _accTimer?.cancel();
  _gyroTimer?.cancel();
  FlutterForegroundTask.stopService();
}

void main() {
  runApp(MaterialApp(
    home: LoginPage(),
  ));
}
