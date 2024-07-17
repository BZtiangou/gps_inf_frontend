import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'obsacc.dart';
import 'obsbt.dart';
import 'obsmap.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _startTimer();
    _fetchQuestions();
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

  void _checkTime() {
    final now = DateTime.now();
    if (now.hour == 11 && now.minute == 0) {
      _showQuestionnaireAlert();
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
        headers: {'Content-Type': 'application/json','Authorization': 'Bearer $accessToken'},
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Observation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _showQuestionnaireAlert,
              child: Text('查看问卷'),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateToGpsObservationPage(context);
              },
              child: Text('GPS Data Observation'),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateToBtObservationPage(context);
              },
              child: Text('BT Data Observation'),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateToAccObservationPage(context);
              },
              child: Text('ACC Data Observation'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: '返回',
        child: Icon(Icons.arrow_back),
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