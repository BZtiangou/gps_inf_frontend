import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PendingLabelsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '待标注信息处理页面',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PendingLabelsScreen(),
    );
  }
}

class PendingLabelsScreen extends StatefulWidget {
  @override
  _PendingLabelsScreenState createState() => _PendingLabelsScreenState();
}

class _PendingLabelsScreenState extends State<PendingLabelsScreen> {
  List<Map<String, dynamic>> _pendingLabels = [];

  @override
  void initState() {
    super.initState();
    _loadPendingLabels();
  }

  Future<void> _loadPendingLabels() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pendingLabelsJson = prefs.getString('pending_labels');
    if (pendingLabelsJson != null) {
      setState(() {
        _pendingLabels = List<Map<String, dynamic>>.from(jsonDecode(pendingLabelsJson));
      });
    }
  }

  Future<void> _savePendingLabels() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_labels', jsonEncode(_pendingLabels));
  }

  Future<void> _saveLabel(Map<String, dynamic> labelData, String newLabel) async {
    // 获取 access_token
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');
    if (accessToken == null) {
      // 处理没有 access_token 的情况
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未登录，请重新登录')),
      );
      return;
    }

    // 调用API保存标注
    try {
      final response = await http.post(
        Uri.parse('http://gps.primedigitaltech.com:8000/api/saveLabel/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'longitude': labelData['longitude'],
          'latitude': labelData['latitude'],
          'label': newLabel,
        }),
      );

      if (response.statusCode == 200) {
        // 更新本地待标注列表
        setState(() {
          _pendingLabels.remove(labelData);
        });
        await _savePendingLabels();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('标注保存失败: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标注保存失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("待标注信息处理页面"),
      ),
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
        child: ListView.builder(
          itemCount: _pendingLabels.length,
          itemBuilder: (context, index) {
            var labelData = _pendingLabels[index];
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '待标注信息',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('经度: ${labelData['longitude']}'),
                      Text('纬度: ${labelData['latitude']}'),
                      Text('当前标注: ${labelData['label']}'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          String? newLabel = await showDialog<String>(
                            context: context,
                            builder: (BuildContext context) {
                              TextEditingController labelController = TextEditingController();
                              return AlertDialog(
                                title: Text('输入新的标注'),
                                content: TextField(
                                  controller: labelController,
                                  decoration: InputDecoration(hintText: "输入新的标注"),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text('取消'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text('确认'),
                                    onPressed: () {
                                      Navigator.of(context).pop(labelController.text);
                                    },
                                  ),
                                ],
                              );
                            },
                          );

                          if (newLabel != null && newLabel.isNotEmpty) {
                            await _saveLabel(labelData, newLabel);
                          }
                        },
                        child: Text('标注'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  runApp(PendingLabelsPage());
}
