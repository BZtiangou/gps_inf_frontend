import 'package:geolocator/geolocator.dart';
import 'package:device_info/device_info.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class GpsPage extends StatefulWidget {
  @override
  _GpsPageState createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  String displayText = 'Welcome to AMAP_INF';

  Future<void> updateText() async {
    String newText = '';
    String longitude = '';
    String latitude = '';
    String deviceInfo = '';
    
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      newText =
          'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
    } catch (e) {
      newText = 'Error fetching location: $e';
    }

  // 获取手机设备信息
    try {
      DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo =
            'Device: ${androidInfo.brand} ${androidInfo.model}\nOS Version: ${androidInfo.version.release}';
      } else {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo =
            'Device: ${iosInfo.name} ${iosInfo.model}\nOS Version: ${iosInfo.systemVersion}';
      }
    } catch (e) {
      deviceInfo = 'Error fetching device info: $e';
    }

    // 构建要发送到后端的数据
    Map<String, dynamic> data = {
      'longitude': longitude,
      'device': deviceInfo,
      'latitude': latitude,
    };

    // 发送POST请求到后端API
    try {
      var response = await http.post(
        Uri.parse('http://gps.primedigitaltech.com:8000/api/updateLocation/'),
        body: data,
      );

      if (response.statusCode == 200) {
        // 请求成功
        print('Data sent successfully!');
      } else {
        // 请求失败
        print('Failed to send data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }

    setState(() {
      displayText = '$newText\n\n $deviceInfo';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS_INF'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              displayText,
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: updateText,
              child: Text('Send INF to Backend'),
            ),
          ],
        ),
      ),
    );
  }
}



