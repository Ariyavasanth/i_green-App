import 'package:flutter/material.dart';

import '../widgets/login_form_widget.dart';
import '../widgets/login_illustration_widget.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return const Row(children: [Expanded(child: LoginFormWidget()), Expanded(child: LoginIllustrationWidget())]);
        }
        // Tablet and mobile share the centered single-column form.
        return const LoginFormWidget();
      }),
    ),
  );
}
