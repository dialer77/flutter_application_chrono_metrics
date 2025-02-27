import 'package:flutter/material.dart';
import 'package:flutter_application_chrono_metrics/pages/testresult_page.dart';
import 'package:flutter_application_chrono_metrics/pages/time_estimation_visual_task.dart';
import 'package:flutter_application_chrono_metrics/pages/time_estimation_auditory_task.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:flutter_application_chrono_metrics/commons/audio_recording_manager.dart';
import 'package:provider/provider.dart';
import 'reaction_test_page.dart';
import 'time_generation_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key, required this.title});

  final String title;

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final List<(String, Widget?)> menuItems = [
    ('동작 반응성 속도 측정', const ReactionTestPage()),
    ('시간 생성', const TimeGenerationPage()),
    ('시간 추정 - 시각 자극', const TimeEstimationVisualTaskPage()),
    ('시간 추정 - 청각 자극', const TimeEstimationAuditoryTaskPage()),
    ('반응 기록', const TestResultPage()),
  ];

  // 사용자 정보 입력을 위한 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();
  bool _isUserInfoSaved = false;

  @override
  void initState() {
    super.initState();
    // 오디오 녹음 매니저 초기화
    AudioRecordingManager().initialize();

    // 이미 저장된 사용자 정보가 있는지 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      if (userInfo != null) {
        setState(() {
          _nameController.text = userInfo.name;
          _userNumberController.text = userInfo.userNumber;
          _isUserInfoSaved = true;
        });
      } else {
        // 저장된 사용자 정보가 없으면 다이얼로그 표시
        _showUserInfoDialog();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userNumberController.dispose();
    super.dispose();
  }

  // 사용자 정보 입력 다이얼로그 표시
  Future<void> _showUserInfoDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // 바깥 영역 터치로 닫기 방지
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('사용자 정보 입력'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _userNumberController,
                  decoration: const InputDecoration(
                    labelText: '학번/ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_isUserInfoSaved) {
                  // 이미 저장된 정보가 있으면 다이얼로그만 닫기
                  Navigator.of(context).pop();
                } else {
                  // 아직 저장된 정보가 없으면 앱 종료 가능하게 안내
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('사용자 정보를 입력해주세요')),
                  );
                }
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _userNumberController.text.isNotEmpty) {
                  // 사용자 정보 저장
                  final userInfo = UserInfomation(
                    name: _nameController.text,
                    userNumber: _userNumberController.text,
                  );
                  Provider.of<UserStateProvider>(context, listen: false).setUserInfo(userInfo);

                  setState(() {
                    _isUserInfoSaved = true;
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('사용자 정보가 저장되었습니다')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이름과 학번/ID를 모두 입력해주세요')),
                  );
                }
              },
              child: const Text('저장'),
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
        title: Text(widget.title),
        actions: [
          // 사용자 정보 표시 및 수정 버튼
          TextButton.icon(
            icon: const Icon(Icons.person),
            label: Text(_isUserInfoSaved ? '${_nameController.text} (${_userNumberController.text})' : '사용자 정보 설정'),
            style: TextButton.styleFrom(
              foregroundColor: _isUserInfoSaved ? Colors.green : Colors.blue,
            ),
            onPressed: _showUserInfoDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: EdgeInsets.only(
              top: constraints.maxHeight * 0.05,
              bottom: constraints.maxHeight * 0.1,
              left: constraints.maxWidth * 0.1,
              right: constraints.maxWidth * 0.1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: menuItems
                  .map((item) => _buildButton(
                        item.$1,
                        constraints.maxHeight * 0.13,
                        constraints.maxWidth * 0.6,
                        item.$2,
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButton(String text, double height, double width, Widget? page) {
    return ElevatedButton(
      onPressed: page != null && _isUserInfoSaved
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: page != null ? (_isUserInfoSaved ? Colors.blue : Colors.grey) : Colors.grey),
        ),
        fixedSize: Size(width, height),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: width * 0.05),
      ),
      child: Text(
        text,
        style: TextStyle(color: page != null ? (_isUserInfoSaved ? Colors.blue : Colors.grey) : Colors.grey, fontSize: height * 0.3),
      ),
    );
  }
}
