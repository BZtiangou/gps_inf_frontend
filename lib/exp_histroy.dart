import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

class ExperimentHistoryPage extends StatefulWidget {
  @override
  _ExperimentHistoryPageState createState() => _ExperimentHistoryPageState();
}

class _ExperimentHistoryPageState extends State<ExperimentHistoryPage> {
  List<dynamic> _expHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchExpHistory();
  }

  Future<void> _fetchExpHistory() async {
    String accessToken = await getAccessToken();
    final url = 'http://gps.primedigitaltech.com:8000/exp/seeExpHistory/';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _expHistory = json.decode(utf8.decode(response.bodyBytes));
        // 将进行中的实验置顶
        _expHistory.sort((a, b) => (b['exit_time'] == null ? 1 : 0) - (a['exit_time'] == null ? 1 : 0));
      });
    } else {
      throw Exception('Failed to load experiment history');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('实验历史'),
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
          child: _expHistory.isEmpty
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _expHistory.length,
                  itemBuilder: (context, index) {
                    final exp = _expHistory[index];
                    final isOngoing = exp['exit_time'] == null;
                    return Card(
                      color: isOngoing ? Colors.red[100] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp['exp_name'],
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: isOngoing ? Colors.red : Colors.black,
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text('加入时间: ${exp['join_time']}'),
                            Text('退出时间: ${exp['exit_time'] ?? '进行中'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
