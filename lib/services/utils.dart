import 'package:flutter/material.dart';

class Utils {
  String formatTimeAgo(Duration duration) {
    if (duration.inDays > 7) {
      return "${duration.inDays ~/ 7} weeks ago";
    } else if (duration.inDays > 0) {
      return "${duration.inDays} days ago";
    } else if (duration.inHours > 0) {
      return "${duration.inHours} hours ago";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes} minutes ago";
    } else if (duration.inSeconds > 0) {
      return "${duration.inSeconds} seconds ago";
    } else {
      return "just now";
    }
  }

  void showLoaderDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevent closing the dialog by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Loading..."),
              ],
            ),
          ),
        );
      },
    );
  }
}
