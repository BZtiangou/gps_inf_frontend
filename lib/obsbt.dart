import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data_observation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

class BtObservationPage extends StatelessWidget {
  const BtObservationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Devices',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BluetoothListScreen(),
    );
  }
}

class BluetoothListScreen extends StatefulWidget {
  const BluetoothListScreen({Key? key}) : super(key: key);

  @override
  _BluetoothListScreenState createState() => _BluetoothListScreenState();
}

class _BluetoothListScreenState extends State<BluetoothListScreen> {
  List<Map<String, dynamic>> bluetoothDevices = [];
  DateTime? startTime;
  DateTime? endTime;

  @override
  void initState() {
    super.initState();
    fetchAndDisplayBTData();
  }

  Future<void> fetchAndDisplayBTData() async {
    String accessToken = await getAccessToken();
    var url = Uri.parse('http://gps.primedigitaltech.com:8000/api/getBTdata/');
    try {
      var response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        var bluetooths = jsonData['bluetooths'];
        List<Map<String, dynamic>> devices = [];
        for (var bluetooth in bluetooths) {
          var timestamp = bluetooth['timestamp'];
          var connectionDevice = bluetooth['connection_device'];
          devices.add({
            'timestamp': timestamp,
            'macAddress': connectionDevice, // Here you can parse the MAC address if needed
          });
        }
        setState(() {
          bluetoothDevices = devices;
        });
      } else {
        print('Failed to load Bluetooth data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Bluetooth data: $e');
    }
  }

  void filterDevicesByTime() {
    setState(() {
      bluetoothDevices = bluetoothDevices.where((device) {
        DateTime deviceTime = DateTime.parse(device['timestamp']);
        if (startTime != null && deviceTime.isBefore(startTime!)) {
          return false;
        }
        if (endTime != null && deviceTime.isAfter(endTime!)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
        filterDevicesByTime();
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        endTime = picked;
        filterDevicesByTime();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙实验'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: bluetoothDevices.length,
              itemBuilder: (context, index) {
                String timestamp = bluetoothDevices[index]['timestamp'];
                String macAddress = bluetoothDevices[index]['macAddress'];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Icon(Icons.radio_button_checked, color: Colors.blue),
                          if (index != bluetoothDevices.length - 1)
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                      SizedBox(width: 16.0),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(timestamp, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4.0),
                              Text('设备信息： $macAddress'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 56.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('开始时间', style: TextStyle(fontSize: 16.0)),
                    Spacer(),
                    TextButton(
                      onPressed: () => _selectStartTime(context),
                      child: Text('请选择时间'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('结束时间', style: TextStyle(fontSize: 16.0)),
                    Spacer(),
                    TextButton(
                      onPressed: () => _selectEndTime(context),
                      child: Text('请选择时间'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 返回到上一级页面
          Navigator.push(context, MaterialPageRoute(builder: (context) => DataObservationPage()),);
        },
        tooltip: '返回',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
