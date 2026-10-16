import 'package:flutter/widgets.dart';

/// [children] with a [gap] between each pair — `Column`/`Row` `spacing:` for
/// Flutter versions that don't have it (CI pins Flutter 3.22).
List<Widget> spaced(double gap, List<Widget> children) => [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: gap, height: gap),
        children[i],
      ],
    ];
