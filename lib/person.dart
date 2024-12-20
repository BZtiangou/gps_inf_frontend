import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'data_observation_page.dart'; // 导入data_observation_page.dart文件以便导航回首页
import 'main.dart'; // 导入main.dart文件以便导航至登录页面
// 导入experiment_selection_page.dart文件以便导航至实验选择页面
import 'my_info.dart'; // 导入my_info.dart文件以便导航至我的信息页面
import 'package:shared_preferences/shared_preferences.dart';
import 'memo.dart';

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
              title: Text('当前实验'),
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
                        content: Text('请先选择一个实验'),
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
                                '本app会根据用户选择的实验，在用户知情的情况下，收集用户的部分信息。\n'
                                '我们致力于保护您的隐私，所有收集到的信息将严格保密，并仅用于实验相关的目的。\n'
                                '1. 请同意授权GPS，蓝牙，网络等权限。\n'
                                '2. 如需要更换实验，请在首页先退出当前实验，完成手机号码验证后，选择新的实验。重新登录后方可生效。\n'
                                '3. 实验生效后，本app支持后台静默数据采集，您无需手动上传数据，但请确保本app处于后台运行状态。\n'
                                '4. 本app会收集您的手机信息，如GPS、蓝牙、网络等，用于实验相关的数据采集。\n'
                                '5. 实验只是采集数据的间隔, 请根据指引或需求选择正确的实验。\n'
                                '6. 实验标注部分，在GPS页面中，请寻找红色的四边形，点击即可进行标注。蓝色四边形则代表已标注区，点击可以查看相关标注信息。\n'
                                '7. 蓝牙标注部分，在蓝牙页面中，请点击未标注部分进行标注，我们已经帮您过滤掉无效蓝牙设备，如仍无法标注，忽略即可。\n'
                                '8. 调查问卷尚未开放，请不要提交问卷。\n'
                                '9. 在个人信息页面可以查看您的个人信息，并且做出相应的修改，暂不支持头像上传，头像部分是统一的。\n'
                                '如有任何疑问，请随时联系开发者+86 17620642718(微信同号)。感谢您的理解与配合。'
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
            label: '随手记',
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
          else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MemoPage()), // 跳转到 MemoPage
          );
          }
        },
      ),
    );
  }
}
