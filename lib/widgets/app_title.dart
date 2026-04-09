import 'package:flutter/material.dart';
import '../services/app_settings.dart';

Widget buildTitle(String title, String pageName) {
  if (!AppSettings.showPageHints) {
    return Text(title);
  }

  return Tooltip(
    message: pageName,
    child: Text(title),
  );
}