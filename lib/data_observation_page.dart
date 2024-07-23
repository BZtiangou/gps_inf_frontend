import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'obsacc.dart';
import 'obsbt.dart';
import 'obsmap.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'person.dart'; // 导入person.dart文件
import 'experiment.dart'; // 导入experiment.dart文件
import 'main.dart';

void main() {
  runApp(MaterialApp(
    home: DataObservationPage(),
  ));
}

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

class DataObservationPage extends StatefulWidget {
  @override
  _DataObservationPageState createState() => _DataObservationPageState();
}

class _DataObservationPageState extends State<DataObservationPage> {
  Timer? _timer;
  late List<Map<String, dynamic>> questions = [];
  final Map<int, dynamic> _answers = {};
  String experimentStatus = '请选择实验'; // 默认状态

  @override
  void initState() {
    super.initState();
    _startTimer();
    _fetchQuestions();
    _checkExperimentStatus();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkTime();
    });
  }

  void _fetchQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('http://gps.primedigitaltech.com:8000/survey/showQuestion/1'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          questions = data.cast<Map<String, dynamic>>();
        });
      } else {
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      print('Error fetching questions: $e');
    }
  }

  void _checkTime() async {
    final now = DateTime.now();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = now.toIso8601String().split('T')[0]; // 获取当前日期字符串（格式：yyyy-MM-dd）

    if (now.hour == 11 && now.minute == 0) {
      // 检查今天是否已经显示过问卷
      String? lastShownDate = prefs.getString('lastQuestionnaireShownDate');
      if (lastShownDate == null || lastShownDate != today) {
        _showQuestionnaireAlert();
        // 更新标志为今天的日期
        await prefs.setString('lastQuestionnaireShownDate', today);
      }
    }
  }

  void _showQuestionnaireAlert() {
    if (questions.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('调查问卷'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildQuestionnaireContent(),
            ),
            actions: [
              TextButton(
                child: Text('提交'),
                onPressed: () {
                  _submitAnswers();
                },
              ),
              TextButton(
                child: Text('取消'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('调查问卷'),
            content: Text('暂无问卷问题可显示'),
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

  List<Widget> _buildQuestionnaireContent() {
    List<Widget> widgets = [];

    for (var question in questions) {
      String questionText = question['question_text'];
      String questionType = question['question_type'];
      String choices = question['choices'];
      int questionId = question['question_id'];

      widgets.add(Text(questionText));

      if (questionType == 'text') {
        widgets.add(TextFormField(
          onChanged: (value) {
            _answers[questionId] = value;
          },
          decoration: InputDecoration(
            hintText: '请输入您的回答',
          ),
        ));
      } else if (questionType == 'choice') {
        List<String> options = choices.split(';').where((element) => element.isNotEmpty).toList();
        widgets.add(DropdownButtonFormField(
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) {
            _answers[questionId] = value;
          },
          hint: Text('请选择一个选项'),
        ));
      }
      widgets.add(SizedBox(height: 16));
    }

    return widgets;
  }

  Future<void> _submitAnswers() async {
    List<Map<String, dynamic>> answersList = _answers.entries.map((entry) {
      return {"question_id": entry.key, "answer_text": entry.value};
    }).toList();

    Map<String, dynamic> data = {
      "survey_id": 1,
      "answers": answersList,
    };
    String accessToken = await getAccessToken();
    try {
      final response = await http.post(
        Uri.parse('http://gps.primedigitaltech.com:8000/survey/sendRes/'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error submitting answers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交错误: $e')),
      );
    }
  }

  Future<void> _checkExperimentStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://gps.primedigitaltech.com:8000/exp/myExp/'),
        headers: {'Authorization': 'Bearer ${await getAccessToken()}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          experimentStatus = '退出实验';
        });
      } else if (response.statusCode == 520) {
        setState(() {
          experimentStatus = '请选择实验';
        });
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking experiment status: $e');
    }
  }

  Future<void> _exitExperiment() async {
    try {
      final response = await http.get(
        Uri.parse('http://gps.primedigitaltech.com:8000/exp/exitExp/'),
        headers: {'Authorization': 'Bearer ${await getAccessToken()}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          experimentStatus = '请选择实验';
        });
        cancelTimers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功退出实验')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出实验失败: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error exiting experiment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('退出实验错误: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('数据观测'),
        automaticallyImplyLeading: false, // 强制隐藏返回箭头
        actions: [
          TextButton(
            onPressed: () {
              if (experimentStatus == '退出实验') {
                _exitExperiment(); // 退出实验
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ExperimentSelectionPage()), // 跳转到ExperimentSelectionPage
                );
              }
            },
            child: Text(
              experimentStatus,
              style: TextStyle(color: const Color.fromARGB(255, 224, 20, 20)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          children: <Widget>[
            _buildGridItem(
              context,
              icon: Icons.gps_fixed,
              label: 'GPS',
              onTap: () => _navigateToGpsObservationPage(context),
            ),
            _buildGridItem(
              context,
              icon: Icons.show_chart,
              label: '加速度',
              onTap: () => _navigateToAccObservationPage(context),
            ),
            _buildGridItem(
              context,
              icon: Icons.bluetooth,
              label: '蓝牙',
              onTap: () => _navigateToBtObservationPage(context),
            ),
            _buildGridItem(
              context,
              icon: Icons.question_answer,
              label: '问卷',
              onTap: () => _showQuestionnaireAlert(),
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
        currentIndex: 0, // 默认选中首页
        onTap: (index) {
          if (index == 2) { // 点击“我的”
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PersonPage()), // 跳转到PersonPage
            );
          }
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, {required IconData icon, required String label, required Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: Colors.blue[100],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 50.0,
              color: Colors.blue[900],
            ),
            SizedBox(height: 16.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              '点击查看我的${label}数据',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToGpsObservationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GpsObservationPage()),
    );
  }

  void _navigateToBtObservationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BtObservationPage()),
    );
  }

  void _navigateToAccObservationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AccObservationPage()),
    );
  }
}
