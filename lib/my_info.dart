import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

Future<Map<String, dynamic>> fetchUserInfo() async {
  String accessToken = await getAccessToken();
  final response = await http.get(
    Uri.parse('http://gps.primedigitaltech.com:8000/api/getUserInfo/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'Accept-Charset': 'utf-8',
    },
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    throw Exception('Failed to load user info');
  }
}

class MyInfoPage extends StatefulWidget {
  @override
  _MyInfoPageState createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  late Future<Map<String, dynamic>> userInfoFuture;

  @override
  void initState() {
    super.initState();
    userInfoFuture = fetchUserInfo();
  }

  void _showEditDialog(String field, String currentValue, Function(String) onUpdate) {
    TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('请输入新的 $field'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入新的 $field',
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确定'),
              onPressed: () {
                onUpdate(controller.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的信息'),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: userInfoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              Map<String, dynamic> userInfo = snapshot.data ?? {};
              return ListView(
                padding: EdgeInsets.all(16.0),
                children: [
                  _buildInfoTile('姓名', userInfo['name'] ?? '暂未登记', 'name'),
                  Divider(),
                  _buildInfoTile('性别', userInfo['gender'] ?? '暂未登记', 'gender'),
                  Divider(),
                  _buildInfoTile('邮箱', userInfo['email'] ?? '暂未登记', 'email'),
                  Divider(),
                  _buildInfoTile('电话', userInfo['phone_number'] ?? '暂未登记', 'phone_number'),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, String field) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      trailing: IconButton(
        icon: Icon(Icons.edit),
        onPressed: () {
          _showEditDialog(title, value, (newValue) {
            // 调用API更新信息
            _updateUserInfo(field, newValue);
          });
        },
      ),
    );
  }

  Future<void> _updateUserInfo(String field, String newValue) async {
    String baseUrl = 'http://gps.primedigitaltech.com:8000/api/';
    String url ='${baseUrl}modify/$field/';
    String accessToken = await getAccessToken();
    final response = await http.post(
      Uri.parse(url), 
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Accept-Charset': 'utf-8',
      },
      body: jsonEncode({field: newValue}),
    );

    if (response.statusCode == 200) {
      // 更新成功后，刷新用户信息
      setState(() {
        userInfoFuture = fetchUserInfo();
      });
    } else {
      // 更新失败处理
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('错误'),
            content: Text('更新信息失败，请稍后再试。'),
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
  }
}
