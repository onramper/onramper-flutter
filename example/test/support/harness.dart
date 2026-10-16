import 'package:flutter/material.dart';
import 'package:onramper_flutter_example/theme/demo_theme.dart';

/// Wraps [child] like the app does: DemoTheme above MaterialApp.
Widget harness(Widget child, {DemoPalette palette = DemoPalette.dark}) =>
    DemoTheme(
      palette: palette,
      child: MaterialApp(
        theme: buildMaterialTheme(palette),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
