import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'data_observation_page.dart'; // 导入data_observation_page.dart文件以便导航回首页
import 'main.dart'; // 导入main.dart文件以便导航至登录页面
import 'experiment.dart'; // 导入experiment_selection_page.dart文件以便导航至实验选择页面
import 'my_info.dart'; // 导入my_info.dart文件以便导航至我的信息页面
import 'package:shared_preferences/shared_preferences.dart';

Future<String> getusername() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? username = prefs.getString('username');
  if (username == null) {
    throw Exception('Username not found in SharedPreferences');
  }
  return username;
}

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

Future<Map<String, dynamic>> fetchExperimentDetails() async {
  String accessToken = await getAccessToken();
  final response = await http.get(
    Uri.parse('http://gps.primedigitaltech.com:8000/exp/myExp/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'Accept-Charset': 'utf-8',
    },
  );

  if (response.statusCode == 200) {
    List<dynamic> experiments = json.decode(utf8.decode(response.bodyBytes));
    return experiments.isNotEmpty ? experiments[0] : {};
  } else {
    throw Exception('Failed to load experiment details');
  }
}

class PersonPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的'),
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
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50.0,
                    backgroundImage: NetworkImage('https://bztiangou.github.io/Richo.github.io/images/head.jpg'), // 使用NetworkImage来加载网络图片
                  ),
                  SizedBox(height: 8.0),
                  FutureBuilder<String>(
                    future: getusername(), // 替换为实际的用户名
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        return Text(
                          snapshot.data ?? 'Unknown',
                          style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.0),
            ListTile(
              leading: Icon(Icons.science, color: Colors.grey),
              title: Text('实验详情'),
              onTap: () async {
                try {
                  Map<String, dynamic> experimentDetails = await fetchExperimentDetails();
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('我的实验'),
                        content: experimentDetails.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: experimentDetails.entries.map((entry) {
                                  return Text('${entry.key}: ${entry.value}');
                                }).toList(),
                              )
                            : Text('暂无实验详情'),
                        actions: [
                          TextButton(
                            child: Text('确定'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                } catch (e) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('错误'),
                        content: Text('获取实验详情失败，请稍后再试。'),
                        actions: [
                          TextButton(
                            child: Text('确定'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.assignment_turned_in, color: Colors.grey),
              title: Text('未填问卷'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('提示'),
                      content: Text('暂时没有未填报告。'),
                      actions: [
                        TextButton(
                          child: Text('确定'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.play_circle_fill, color: Colors.grey),
              title: Text('使用说明'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('使用说明'),
                      content: Text(
                        '本app会根据用户选择的实验，在用户知情的情况下，收集用户的部分信息。'
                        '我们致力于保护您的隐私，所有收集到的信息将严格保密，并仅用于实验相关的目的。'
                        '如有任何疑问，请随时联系我们的开发者或指导老师。感谢您的理解与配合。'
                      ),
                      actions: [
                        TextButton(
                          child: Text('确定'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.science, color: Colors.grey),
              title: Text('选择实验'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ExperimentSelectionPage()), // 跳转到实验选择页面
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.info, color: Colors.grey),
              title: Text('我的信息'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyInfoPage()), // 跳转到我的信息页面
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.grey),
              title: Text('退出登录'),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // 结束所有定时器
                cancelTimers();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: '信息',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DataObservationPage()), // 跳转到首页
            );
          }
        },
      ),
    );
  }
}
