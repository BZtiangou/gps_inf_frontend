import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '蓝牙标注页面',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BtLabelPage(),
    );
  }
}

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

class BtLabelPage extends StatefulWidget {
  @override
  _BtLabelPageState createState() => _BtLabelPageState();
}

class _BtLabelPageState extends State<BtLabelPage> {
  List<Map<String, dynamic>> _devices = [];
  String _selectedDevice = '';
  String _label = '';
  bool _isLabelInputVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  void _fetchDevices() async {
    try {
      String accessToken = await getAccessToken();
      final response = await http.get(
        Uri.parse('http://gps.primedigitaltech.com:8000/api/getBTLabel/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(json.decode(utf8.decode(response.bodyBytes)));
        });
      } else {
        print("Failed to fetch devices");
      }
    } catch (e) {
      print("Error fetching devices: $e");
    }
  }

  void _updateLabel() async {
    try {
      String accessToken = await getAccessToken();
      final response = await http.post(
        Uri.parse('http://gps.primedigitaltech.com:8000/api/updateBTlabel/'),
        body: json.encode({'bt_device': _selectedDevice, 'label': _label}),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _fetchDevices();
          _isLabelInputVisible = false;
          _label = '';
        });
      } else {
        print("Failed to update label");
      }
    } catch (e) {
      print("Error updating label: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('蓝牙标注页面'),
      ),
      body: Container(
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
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isLabeled = device['label']?.isNotEmpty ?? false;
                    return ListTile(
                      title: Text(device['bt_device']),
                      subtitle: Text(isLabeled ? "已标注为: ${device['label']}。点击可进行修改" : '未标注，点击标注'),
                      onTap: () {
                        setState(() {
                          _selectedDevice = device['bt_device'];
                          _label = device['label'] ?? '';
                          _isLabelInputVisible = true;
                        });
                      },
                    );
                  },
                ),
              ),
              if (_isLabelInputVisible)
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(labelText: '输入标注'),
                      onChanged: (value) {
                        setState(() {
                          _label = value;
                        });
                      },
                      controller: TextEditingController(text: _label),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: _selectedDevice.isEmpty ? null : _updateLabel,
                          child: Text('确认'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDevice = '';
                              _label = '';
                              _isLabelInputVisible = false;
                            });
                          },
                          child: Text('取消'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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
                // 添加其他输入框和按钮
              ],
            ),
          ),
        ),
      ),
    );
  }
}
