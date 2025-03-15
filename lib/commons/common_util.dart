import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_state_provider.dart';
import '../datas/user_infomation.dart';

class CommonUtil {
  static const TextStyle snackBarTextStyle = TextStyle(
    fontSize: 36,
  );

  static Future<void> showUserInfoDialog({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController userNumberController,
  }) async {
    // 기존 유저 정보 가져오기
    final existingUserInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
    if (existingUserInfo != null) {
      nameController.text = existingUserInfo.name;
      userNumberController.text = existingUserInfo.userNumber;
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        void handleSubmit() {
          if (nameController.text.isEmpty || userNumberController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('모든 정보를 입력해주세요.', style: snackBarTextStyle)),
            );
            return;
          }

          final userInfo = UserInfomation(
            name: nameController.text,
            userNumber: userNumberController.text,
          );

          Provider.of<UserStateProvider>(context, listen: false).setUserInfo(userInfo);
          Navigator.of(context).pop();
        }

        return AlertDialog(
          title: const Text('사용자 정보 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '이름을 입력하세요',
                ),
                onSubmitted: (_) => handleSubmit(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userNumberController,
                decoration: const InputDecoration(
                  labelText: '학번',
                  hintText: '학번을 입력하세요',
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => handleSubmit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: handleSubmit,
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
