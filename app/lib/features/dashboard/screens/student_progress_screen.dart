import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/student_progress_view.dart';

/// Full-page detail view for one student, pushed from the teacher
/// dashboard's student list.
class StudentProgressScreen extends StatelessWidget {
  final String studentId;
  final String studentName;

  const StudentProgressScreen({super.key, required this.studentId, required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.adminTheme,
      child: Scaffold(
        appBar: AppBar(title: Text(studentName)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: StudentProgressView(studentId: studentId),
      ),
    );
  }
}
