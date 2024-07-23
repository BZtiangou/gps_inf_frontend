import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'data_observation_page.dart';

class ExperimentSelectionPage extends StatefulWidget {
  @override
  _ExperimentSelectionPageState createState() => _ExperimentSelectionPageState();
}
  
Future<String> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');
    if (accessToken == null) {
      throw Exception('Access token not found in SharedPreferences');
    }
    return accessToken;
  }

class _ExperimentSelectionPageState extends State<ExperimentSelectionPage> {
  Future<List<dynamic>> _fetchExperiments() async {
    final response = await http.get(Uri.parse('http://gps.primedigitaltech.com:8000/exp/seeExp/'));
    if (response.statusCode == 200) {
      // 使用 UTF-8 解码
      final List<dynamic> experiments = json.decode(utf8.decode(response.bodyBytes));
      return experiments;
    } else {
      throw Exception('Failed to load experiments');
    }
  }

  Future<void> _joinExperiment(String expName) async {
    String accessToken = await getAccessToken();

    final response = await http.post(
      Uri.parse('http://gps.primedigitaltech.com:8000/exp/chooseExp/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, String>{
        'exp_name': expName,
      }),
    );

    if (response.statusCode == 200) {
      // Successfully joined the experiment
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功加入/更换实验$expName! 新实验将在重新登录后生效!')),
      );
            // 跳转到 DataObservationPage
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DataObservationPage()),
      );



    
    } else {
      // Failed to join the experiment
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入实验失败: $expName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('请选你想要加入的实验'),
        automaticallyImplyLeading: false, // 强制隐藏返回箭头
        centerTitle: true,
        backgroundColor: Colors.blue[200],
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
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<List<dynamic>>(
            future: _fetchExperiments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Failed to load experiments'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No experiments available'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final experiment = snapshot.data![index];
                    return _buildExperimentCard(experiment);
                  },
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentCard(dynamic experiment) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.grey),
                SizedBox(width: 8.0),
                Text(
                  experiment['exp_name'],
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            Text(
              experiment['description'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(experiment['exp_name']),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('描述: ${experiment['description']}'),
                        Text('开始时间: ${experiment['start_time']}'),
                        Text('结束时间: ${experiment['end_time']}'),
                        Text('GPS 频率: ${experiment['gps_frequency']}'),
                        Text('加速度计频率: ${experiment['acc_frequency']}'),
                        Text('蓝牙频率: ${experiment['bt_frequency']}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('关闭'),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                '点击查看更多',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            SizedBox(height: 8.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _joinExperiment(experiment['exp_name']),
                child: Text('加入实验'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ExperimentSelectionPage(),
  ));
}
