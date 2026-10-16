import 'package:flutter/material.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import '../app/demo_controller.dart';
import '../config/environments.dart';
import '../logging/log_file_store.dart';
import '../logging/log_settings.dart';
import '../logging/share_log_file.dart';
import '../platform/ios_diagnostics.dart';
import '../theme/demo_theme.dart';
import '../utils/format.dart';
import '../widgets/demo_card.dart';
import '../widgets/diagnostics_card.dart';
import '../widgets/event_log_card.dart';
import '../widgets/segmented.dart';
import '../widgets/sheet_header.dart';
import '../widgets/switch_row.dart';

/// RN `SettingsSheet`.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.demo,
    required this.logSettings,
    required this.logStore,
    required this.shareFile,
  });

  final DemoController demo;
  final LogSettings logSettings;
  final LogFileStore logStore;
  final ShareLogFile shareFile;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _clearing = false;
  String? _clearError;
  String _sdkVersion = '…';
  IosAppIdentifiers? _ids;

  @override
  void initState() {
    super.initState();
    OnramperClient.sdkVersion().then(
      (v) => mounted ? setState(() => _sdkVersion = v) : null,
      onError: (Object _) => mounted ? setState(() => _sdkVersion = '?') : null,
    );
    IosDiagnostics.readAppIdentifiers().then(
      (ids) => mounted ? setState(() => _ids = ids) : null,
      onError: (Object _) => mounted
          ? setState(() =>
              _ids = const IosAppIdentifiers(bundleId: 'unknown', teamId: 'unknown'))
          : null,
    );
  }

  Future<void> _clearSessions() async {
    setState(() {
      _clearing = true;
      _clearError = null;
    });
    try {
      await widget.demo.clearLocalSessions();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final d = describeError(e);
      if (mounted) setState(() => _clearError = '${d.code} — ${d.message}');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final demo = widget.demo;
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) => Column(children: [
        SheetHeader(title: 'Settings', onClose: () => Navigator.pop(context)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                DemoCard(
                  title: 'Environment',
                  footer: 'Switching signs out, then re-initializes the SDK against the '
                      'selected environment.',
                  children: [
                    Segmented<DemoEnvironment>(
                      options: [
                        for (final e in DemoEnvironment.values) SegmentOption(e, e.label),
                      ],
                      value: demo.environment,
                      disabled: demo.isSwitching,
                      onChanged: demo.switchEnvironment,
                    ),
                    if (demo.isSwitching)
                      Row(spacing: 8, children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(p.accent)),
                        ),
                        Text('Switching environment…',
                            style: TextStyle(color: p.textSecondary)),
                      ]),
                  ],
                ),
                DemoCard(
                  footer: 'Signs out of OnramperID, resets checkout state, and '
                      're-initializes with a fresh demo session.',
                  children: [
                    Semantics(
                      button: true,
                      label: 'Clear local sessions',
                      child: GestureDetector(
                        onTap: _clearing ? null : _clearSessions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(DemoRadius.button),
                          ),
                          child: _clearing
                              ? SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(p.danger)))
                              : Text('Clear local sessions',
                                  style: TextStyle(
                                      color: p.danger,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    if (_clearError != null)
                      Text(_clearError!, style: TextStyle(color: p.danger)),
                  ],
                ),
                DemoCard(
                  title: 'Appearance',
                  footer: 'Re-initializes the SDK with the matching theme.',
                  children: [
                    SwitchRow(
                      label: 'Dark mode',
                      value: demo.isDark,
                      onChanged: demo.setDarkMode,
                    ),
                  ],
                ),
                DiagnosticsCard(
                  settings: widget.logSettings,
                  store: widget.logStore,
                  share: widget.shareFile,
                ),
                EventLogCard(log: demo.eventLog),
                DemoCard(title: 'About', children: [
                  for (final (label, value) in [
                    ('Library', OnramperClient.wrapperVersion),
                    ('OnramperSDK', _sdkVersion),
                    ('Environment', demo.environment.label),
                    ('Bundle ID', _ids?.bundleId ?? '…'),
                    ('Team ID', _ids?.teamId ?? '…'),
                  ])
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(label, style: TextStyle(color: p.textSecondary)),
                      Flexible(
                        child: Text(value,
                            textAlign: TextAlign.end, style: TextStyle(color: p.text)),
                      ),
                    ]),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
