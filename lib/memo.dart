import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_observation_page.dart';
import 'person.dart';

class MemoPage extends StatefulWidget {
  @override
  _MemoPageState createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  final TextEditingController _memoController = TextEditingController();
  List<Map<String, String>> _memoList = [];
  String _selectedCategory = '全部';
  final List<String> _categories = [
    '全部',
    '日常生活',
    '学习',
    '工作',
    '购物',
    '健康',
    '运动',
    '旅行',
    '其他'
  ];
  String _currentCategory = '日常生活';

  @override
  void initState() {
    super.initState();
    _loadMemo();
  }

  Future<void> _loadMemo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> memoData = prefs.getStringList('memoList') ?? [];
    setState(() {
      _memoList = memoData.map((item) {
        List<String> parts = item.split('||');
        return {'text': parts[0], 'time': parts[1], 'category': parts[2]};
      }).toList();
    });
  }

  Future<void> _saveMemo() async {
    if (_memoController.text.isNotEmpty) {
      String currentTime = DateTime.now().toIso8601String().substring(0, 19); // 精确到秒
      setState(() {
        _memoList.add({
          'text': _memoController.text,
          'time': currentTime,
          'category': _currentCategory
        });
        _memoController.clear();
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> memoData = _memoList
          .map((item) => '${item['text']}||${item['time']}||${item['category']}')
          .toList();
      await prefs.setStringList('memoList', memoData);
    }
  }

  Future<void> _deleteMemo(int index) async {
    setState(() {
      _memoList.removeAt(index);
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> memoData = _memoList
        .map((item) => '${item['text']}||${item['time']}||${item['category']}')
        .toList();
    await prefs.setStringList('memoList', memoData);
  }

  List<Map<String, String>> _getFilteredMemos() {
    if (_selectedCategory == '全部') {
      return _memoList;
    }
    return _memoList.where((item) => item['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> filteredMemos = _getFilteredMemos();

    return Scaffold(
      appBar: AppBar(
        title: Text('随手记'),
        centerTitle: true,
        backgroundColor: Colors.blue[200],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[100]!, Colors.blue[200]!],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _memoController,
                    decoration: InputDecoration(
                      labelText: '输入您的随手记',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '请选择该条随手记的分类归属：',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _currentCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _currentCategory = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _saveMemo,
              child: Text('保存'),
            ),
            SizedBox(height: 10),
            Text(
              '已记录的随手记：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            DropdownButton<String>(
              value: _selectedCategory,
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredMemos.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(filteredMemos[index]['text'] ?? ''),
                      subtitle: Text(
                          '分类: ${filteredMemos[index]['category']}, 保存时间: ${filteredMemos[index]['time']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteMemo(index);
                        },
                      ),
                    ),
                  );
                },
              ),
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
              MaterialPageRoute(builder: (context) => DataObservationPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PersonPage()),
            );
          }
        },
      ),
    );
  }
}
