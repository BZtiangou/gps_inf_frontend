import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info/device_info.dart';

    // List<Map<String, dynamic>> bluetoothDataList = [];
    // for (ScanResult result in scanResults) {
    //   bluetoothDataList.add({
    //     'name': result.device.name,
    //     'id': result.device.id.toString(),
    //     'rssi': result.rssi,
    //   });
 // 拼接所有的 Bluetooth 设备 ID
   
    // }

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();
    initializeFlutterBlue();
  }

  Future<void> initializeFlutterBlue() async {
    await requestPermissions();
    startScan();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect
    ].request();
  }

  void startScan() {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    // flutterBlue.stopScan(); // 不需要在这里停止扫描，否则只会扫描一次就停止了
  }

  Future<void> sendDataToAPI() async {
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

    // 封装附近设备信息
    // 获取所有设备的名称列表
    List<String> deviceNames = scanResults.map((result) {
      return result.device.remoteId.toString();
    }).toList();

    // 将设备名称列表连接成一个字符串，使用逗号分隔
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
      print('Data sent successfully');
    } else {
      print('Failed to send data. Error: ${response.reasonPhrase}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Devices'),
      ),
      body: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          ScanResult result = scanResults[index];
          return ListTile(
            title: Text(result.device.name.isNotEmpty ? result.device.name : 'Unknown Device'),
            subtitle: Text(result.device.id.toString()),
            trailing: Text('${result.rssi} dBm'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await sendDataToAPI();
        },
        child: Icon(Icons.send),
      ),
    );
  }
}