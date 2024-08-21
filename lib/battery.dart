// battery_info_page.dart
import 'package:flutter/material.dart';
import 'package:battery_info/battery_info_plugin.dart';
import 'package:battery_info/model/android_battery_info.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryInfoPage extends StatefulWidget {
  @override
  _BatteryInfoPageState createState() => _BatteryInfoPageState();
}

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

class _BatteryInfoPageState extends State<BatteryInfoPage> {
  String _batteryLevel = '未知';
  String _chargingStatus = '未知';

  @override
  void initState() {
    super.initState();
    _getBatteryInfo();
  }

  Future<void> _getBatteryInfo() async {
    // 获取 Android 电池信息
    AndroidBatteryInfo? androidInfo = await BatteryInfoPlugin().androidBatteryInfo;
    final batteryLevel = androidInfo?.batteryLevel?.toDouble() ?? 0.0;  // 转换为 double
    final chargingStatus = '${androidInfo?.chargingStatus ?? '未知'}';

    // 更新 UI
    setState(() {
      _batteryLevel = '${batteryLevel.toStringAsFixed(2)}%';  // 保留两位小数
      _chargingStatus = chargingStatus;
    });

    // 发送 POST 请求到指定 API
    await _sendBatteryInfoToServer(batteryLevel, chargingStatus);
  }

  Future<void> _sendBatteryInfoToServer(double batteryLevel, String chargingStatus) async {
    String accessToken = await getAccessToken();
    const url = 'http://gps.primedigitaltech.com:8000/sensor/updateBattery/';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: json.encode({
        'battery_level': batteryLevel,  // 发送 float 类型
        'battery_status': chargingStatus,  // 发送 String 类型
      }),
    );

    if (response.statusCode == 200) {
      print('电池信息成功发送');
    } else {
      print('发送电池信息失败: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Android Battery Info'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('电池电量: $_batteryLevel', style: TextStyle(fontSize: 24)),
            SizedBox(height: 16),
            Text('充电状态: $_chargingStatus', style: TextStyle(fontSize: 24)),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _getBatteryInfo,
              child: Text('刷新电池信息'),
            ),
          ],
        ),
      ),
    );
  }
}
