import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/services.dart';

class MyTaskHandler extends TaskHandler {
  String _deviceInfo = ''; // 初始化为空字符串
  dynamic _wakeLock; // 引入 WakeLock

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 初始化 WakeLock
    await _initWakeLock();

    // 获取初始设备信息
    _deviceInfo = await _getDeviceInfo();
    print('Task started at $timestamp with device info: $_deviceInfo');

    // 获取并设置实验配置信息
    String accessToken = await _getAccessToken();
    await _fetchExperimentInfo(accessToken);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    print('Event triggered at $timestamp');
    // 收集并发送蓝牙数据
    collectAndSendBluetoothData();
    // 收集并发送 GPS 数据
    collectAndSendGPSData();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // 清理 WakeLock
    await _releaseWakeLock();
    print('Task destroyed at $timestamp');
  }

  @override
  void onNotificationPressed() {
    // 处理通知点击事件
  }

  // 初始化 WakeLock
  Future<void> _initWakeLock() async {
    try {
      const methodChannel = MethodChannel('wake_lock');
      // 调用平台方法来启用 WakeLock
      _wakeLock = await methodChannel.invokeMethod('acquireWakeLock');
      print('WakeLock acquired');
    } catch (e) {
      print('Failed to acquire WakeLock: $e');
    }
  }

  // 释放 WakeLock
  Future<void> _releaseWakeLock() async {
    try {
      const methodChannel = MethodChannel('wake_lock');
      await methodChannel.invokeMethod('releaseWakeLock');
      print('WakeLock released');
    } catch (e) {
      print('Failed to release WakeLock: $e');
    }
  }

  Future<void> _fetchExperimentInfo(String accessToken) async {
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
        int btFrequency = experiment['bt_frequency'];

        // 根据频率值调整任务执行间隔
        print('Experiment frequencies - GPS: $gpsFrequency, BT: $btFrequency');
      }
    }
  }

  // 收集蓝牙数据的函数
  Future<void> collectAndSendBluetoothData([String? deviceInfo]) async {
    deviceInfo ??= _deviceInfo; // 使用默认设备信息
    List<String> bluetoothDataList = [];
    Set<String> deviceSet = {}; // 用于去重
    FlutterBluePlus.setOptions(restoreState: true);

    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          for (var result in results) {
            String deviceName = result.device.name.isNotEmpty
                ? result.device.name
                : 'undefined';
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
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 5),
        androidScanMode: AndroidScanMode.lowPower
    );

    // wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

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

  // 收集 GPS 数据的函数
  Future<void> collectAndSendGPSData() async {
    AMapFlutterLocation locationPlugin = AMapFlutterLocation();
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    AMapFlutterLocation.setApiKey(
        "d33074d34e5524ed087ce820363a1779", "your_ios_key");

    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult == ConnectivityResult.wifi ||
        connectivityResult == ConnectivityResult.mobile;

    AMapLocationOption locationOption = AMapLocationOption();
    locationOption.onceLocation = true;
    locationOption.needAddress = false;
    locationOption.locationMode = isConnected
        ? AMapLocationMode.Hight_Accuracy
        : AMapLocationMode.Device_Sensors;
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

    String accessToken = await _getAccessToken();

    var response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/sensor/updateLocation/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(
          {'longitude': longitude, 'latitude': latitude, 'accuracy': accuracy}),
    );

    if (response.statusCode == 200) {
      print('GPS data sent successfully');
    } else {
      print('Failed to send GPS data. Error: ${response.reasonPhrase}');
    }
  }

  Future<String> _getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  Future<String> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return 'Device: ${androidInfo.model}, OS: ${androidInfo.version.release}';
  }
}
