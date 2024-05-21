import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'package:device_info/device_info.dart';

class AcclPage extends StatefulWidget {
  @override
  _AcclPageState createState() => _AcclPageState();
}

class _AcclPageState extends State<AcclPage> {
  List<double> _accelerometerValues = [0, 0, 0];

  @override
  void initState() {
    super.initState();
    // 监听加速度传感器数据
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = [event.x, event.y, event.z];
        sendDataToAPI(_accelerometerValues);
      });
    });
  }

  Future<void> sendDataToAPI(List<double> accelerometerValues) async {
    String deviceInfo = '';
    // 获取手机设备信息
    try {
      DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo = 'Device: ${androidInfo.brand} ${androidInfo.model}\nOS Version: ${androidInfo.version.release}';
      } else {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo = 'Device: ${iosInfo.name} ${iosInfo.model}\nOS Version: ${iosInfo.systemVersion}';
      }
    } catch (e) {
      deviceInfo = 'Error fetching device info: $e';
    }
    try {
    Map<String, dynamic> data = {
      'acc_x': '${accelerometerValues[0]}',
      'acc_y': '${accelerometerValues[1]}',
      'acc_z': '${accelerometerValues[2]}',
      'device':deviceInfo,
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
    } catch (e) {
      print('Error sending accelerometer data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Accelerometer Data'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'Accelerometer Values:',
              style: TextStyle(fontSize: 20.0),
            ),
            SizedBox(height: 20.0),
            Text(
              'X: ${_accelerometerValues[0]}',
              style: TextStyle(fontSize: 18.0),
            ),
            Text(
              'Y: ${_accelerometerValues[1]}',
              style: TextStyle(fontSize: 18.0),
            ),
            Text(
              'Z: ${_accelerometerValues[2]}',
              style: TextStyle(fontSize: 18.0),
            ),
          ],
        ),
      ),
    );
  }
}
