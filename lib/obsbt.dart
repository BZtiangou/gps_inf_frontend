import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data_observation_page.dart' ;
import 'package:shared_preferences/shared_preferences.dart';

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
        var jsonData = jsonDecode(response.body);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
      ),
      body: ListView.builder(
        itemCount: bluetoothDevices.length,
        itemBuilder: (context, index) {
          String timestamp = bluetoothDevices[index]['timestamp'];
          String macAddress = bluetoothDevices[index]['macAddress'];

          return ListTile(
            title: Text('Timestamp: $timestamp'),
            subtitle: Text('MAC Address: $macAddress'),
            trailing: Icon(Icons.bluetooth),
            onTap: () {
              // Handle tap on the list item if needed
            },
          );
        },
      ),
        floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 返回到上一级页面
          Navigator.push(context,MaterialPageRoute(builder: (context) => DataObservationPage()),);
        },
        tooltip: '返回',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
