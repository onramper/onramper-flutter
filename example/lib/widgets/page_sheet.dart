import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';

/// Full-height modal sheet, the Flutter take on RN `presentationStyle="pageSheet"`.
/// The background is read inside the route so a theme change repaints it.
Future<T?> showPageSheet<T>(BuildContext context,
        {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: ColoredBox(
          color: DemoTheme.of(context).contentBg,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
