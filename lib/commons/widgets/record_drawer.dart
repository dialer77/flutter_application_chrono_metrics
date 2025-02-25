import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';

class RecordDrawer extends StatelessWidget {
  final Widget record;
  final String title;
  final String path;

  const RecordDrawer({
    super.key,
    required this.record,
    required this.path,
    this.title = '반응 속도 기록',
  });

  @override
  Widget build(BuildContext context) {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Container(
                height: constraints.maxHeight * 0.1,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: constraints.maxHeight * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 유저 정보 섹션
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('이름: ${userInfo?.name ?? "미입력"}'),
                        const SizedBox(width: 10),
                        Text('학번: ${userInfo?.userNumber ?? "미입력"}'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: '저장 폴더 열기',
                          onPressed: () async {
                            if (Platform.isWindows) {
                              final path = this.path.replaceAll('/', '\\');
                              Process.run('explorer', [path]);
                            } else if (Platform.isMacOS) {
                              Process.run('open', [path]);
                            } else if (Platform.isLinux) {
                              Process.run('xdg-open', [path]);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 테스트 결과 목록
              Expanded(
                child: record,
              ),
            ],
          );
        },
      ),
    );
  }
}
