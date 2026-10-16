import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import '../app/demo_controller.dart';
import '../checkout/checkout_controller.dart';
import '../checkout/prefill.dart';
import '../checkout/request.dart';
import '../config/catalog.dart';
import '../logging/event_log.dart';
import '../logging/log_file_store.dart';
import '../logging/log_settings.dart';
import '../logging/share_log_file.dart';
import '../theme/demo_theme.dart';
import '../utils/debounced_text.dart';
import '../utils/format.dart';
import '../widgets/demo_card.dart';
import '../widgets/demo_dropdown.dart';
import '../widgets/demo_field.dart';
import '../widgets/event_log_card.dart';
import '../widgets/option_sheet.dart';
import '../widgets/page_sheet.dart';
import '../widgets/prefill_card.dart';
import '../widgets/quote_card.dart';
import '../widgets/segmented.dart';
import '../widgets/status_box.dart';
import '../widgets/switch_row.dart';
import '../widgets/tile.dart';
import 'settings_sheet.dart';

/// RN `BuyCryptoScreen`.
class BuyCryptoScreen extends StatefulWidget {
  const BuyCryptoScreen({
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
  State<BuyCryptoScreen> createState() => _BuyCryptoScreenState();
}

class _BuyCryptoScreenState extends State<BuyCryptoScreen> {
  BuyForm _form = const BuyForm();
  PrefillInput _prefillDraft = const PrefillInput();
  PrefillInput _prefill = const PrefillInput();
  Timer? _prefillTimer;
  String? _actionError;

  late final CheckoutController _checkout =
      CheckoutController(log: widget.demo.eventLog.add);
  late final DebouncedText _amount = DebouncedText(
      initial: _form.amount,
      onCommit: (v) => _setForm(_form.copyWith(amount: v)));
  late final DebouncedText _wallet = DebouncedText(
      initial: _form.wallet,
      onCommit: (v) => _setForm(_form.copyWith(wallet: v)));

  DemoController get _demo => widget.demo;

  @override
  void initState() {
    super.initState();
    _sync();
    _demo.addListener(_onDemoChanged);
    _checkout.addListener(_rebuild);
  }

  @override
  void dispose() {
    _demo.removeListener(_onDemoChanged);
    _checkout.dispose();
    _amount.dispose();
    _wallet.dispose();
    _prefillTimer?.cancel();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onDemoChanged() {
    _sync();
    setState(() {});
  }

  void _sync() => _checkout.update(
        client: _demo.client,
        form: _form,
        prefill: _prefill,
        palette: DemoPalette.of(_demo.isDark),
      );

  void _setForm(BuyForm form) {
    setState(() => _form = form);
    _amount.sync(form.amount);
    _wallet.sync(form.wallet);
    _sync();
  }

  /// Text edits settle after the typing debounce; the two switches settle
  /// immediately.
  void _changePrefill(PrefillInput next) {
    final switched = next.enabled != _prefillDraft.enabled ||
        next.sendEmail != _prefillDraft.sendEmail;
    setState(() => _prefillDraft = next);
    _prefillTimer?.cancel();
    if (switched) {
      _settlePrefill();
    } else {
      _prefillTimer = Timer(typingDebounce, _settlePrefill);
    }
  }

  void _settlePrefill() {
    if (!mounted) return;
    setState(() => _prefill = _prefillDraft);
    _sync();
  }

  Future<void> _runAction(
      String label, Future<void> Function(OnramperClient c) action) async {
    final c = _demo.client;
    if (c == null) return;
    setState(() => _actionError = null);
    try {
      await action(c);
      if (!mounted) return;
      _demo.clearOutcome();
      _demo.eventLog.add(EventLevel.info, '$label OK');
      _checkout.refresh();
    } catch (e) {
      final d = describeError(e);
      if (!mounted) return;
      setState(() => _actionError = '$label failed: ${d.code} — ${d.message}');
      _demo.eventLog
          .add(EventLevel.error, '$label failed: ${d.code} — ${d.message}');
    }
  }

  void _recoverCheckout() {
    setState(() => _actionError = null);
    _demo.clearOutcome();
    _checkout.refresh();
  }

  void _openSettings() => showPageSheet<void>(
        context,
        builder: (_) => SettingsSheet(
          demo: _demo,
          logSettings: widget.logSettings,
          logStore: widget.logStore,
          shareFile: widget.shareFile,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final insets = MediaQuery.paddingOf(context);
    // The header is custom (no AppBar), so set the status bar style here.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.contentBg,
        body: Column(children: [
          _header(p, insets.top),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, insets.bottom + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  _countryCard(),
                  DemoCard(title: 'Select currency', children: [
                    TileRow(children: [
                      for (final c in DemoCrypto.values)
                        Tile(
                          label: c.symbol,
                          sublabel: c.displayName,
                          selected: c == _form.crypto,
                          onTap: () => _setForm(_form.withCrypto(c)),
                          leading: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: c.color, shape: BoxShape.circle),
                          ),
                        ),
                    ]),
                  ]),
                  DemoCard(
                      title: 'Wallet address (${_form.crypto.network})',
                      children: [
                        DemoField(
                          controller: _wallet.controller,
                          mono: true,
                          placeholder: 'Wallet address',
                          onChanged: _wallet.onChanged,
                        ),
                      ]),
                  _amountCard(p),
                  DemoCard(title: 'Payment method', children: [
                    TileRow(children: [
                      for (final m in DemoPaymentMethod.values)
                        Tile(
                          label: m.label,
                          selected: m == _form.paymentMethod,
                          onTap: () =>
                              _setForm(_form.copyWith(paymentMethod: m)),
                        ),
                    ]),
                  ]),
                  DemoCard(title: 'Onramp', children: [
                    DemoDropdown<String?>(
                      label: 'Onramp',
                      options: [
                        for (final (id, label) in onrampOptions)
                          SegmentOption(id, label)
                      ],
                      value: _form.onramp,
                      onChanged: (v) =>
                          _setForm(_form.copyWith(onramp: () => v)),
                    ),
                  ]),
                  PrefillCard(value: _prefillDraft, onChanged: _changePrefill),
                  _checkoutSection(p),
                  Row(spacing: 8, children: [
                    _actionButton('Reset', p.danger,
                        () => _runAction('reset', (c) => c.reset())),
                    _actionButton('Log out', p.warning,
                        () => _runAction('sign out', (c) => c.signOut())),
                  ]),
                  Text(
                    'SDK: ${_demo.status == InitStatus.ready ? _demo.sdkState.name : _demo.status.name}',
                    style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12,
                        fontFamily: kMonoFont),
                  ),
                  ..._statusBoxes(),
                  EventLogCard(log: _demo.eventLog),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(DemoPalette p, double top) => Container(
        color: p.headerBg,
        padding: EdgeInsets.fromLTRB(16, top + 8, 16, 12),
        child: Row(spacing: 12, children: [
          Expanded(
            child: Text('Buy Crypto',
                style: TextStyle(
                    color: p.text, fontSize: 28, fontWeight: FontWeight.w700)),
          ),
          if (_demo.status == InitStatus.initializing)
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation(p.accent)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: p.accent, borderRadius: BorderRadius.circular(8)),
            child: Text(_demo.environment.label,
                style: TextStyle(
                    color: p.onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          Semantics(
            button: true,
            label: 'Settings',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openSettings,
              child: ExcludeSemantics(
                child:
                    Text('⚙︎', style: TextStyle(color: p.text, fontSize: 24)),
              ),
            ),
          ),
        ]),
      );

  Widget _countryCard() => DemoCard(children: [
        SwitchRow(
          label: 'Override country and state',
          value: _form.countryOverride,
          onChanged: (v) => _setForm(_form.copyWith(countryOverride: v)),
        ),
        if (_form.countryOverride)
          Segmented<DemoCountry>(
            options: [
              for (final c in DemoCountry.values)
                SegmentOption(c, '${c.flag} ${c.label}'),
            ],
            value: _form.country,
            onChanged: (c) => _setForm(_form.withCountry(c)),
          ),
        if (_form.countryOverride && _form.country == DemoCountry.us)
          Tile(
            label: usStates
                    .where((s) => s.code == _form.usState)
                    .map((s) => s.name)
                    .firstOrNull ??
                _form.usState,
            sublabel: 'US state — tap to change',
            selected: false,
            onTap: () => showOptionSheet(
              context,
              title: 'US state',
              options: [
                for (final s in usStates)
                  SegmentOption(s.code, '${s.name} (${s.code})'),
              ],
              selected: _form.usState,
              onSelect: (code) => _setForm(_form.copyWith(usState: code)),
            ),
          ),
      ]);

  Widget _amountCard(DemoPalette p) {
    final hint = parseAmount(_amount.controller.text) == null
        ? 'Enter an amount greater than 0'
        : _checkout.amountHint;
    return DemoCard(title: 'Amount', children: [
      Row(spacing: 8, children: [
        Expanded(
          child: DemoField(
            controller: _amount.controller,
            mono: true,
            semanticsLabel: 'Amount in ${_form.fiat.label}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              _amount.onChanged(v);
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: Segmented<DemoFiat>(
            options: [
              for (final f in DemoFiat.values) SegmentOption(f, f.label)
            ],
            value: _form.fiat,
            onChanged: (f) => _setForm(_form.copyWith(fiat: f)),
          ),
        ),
      ]),
      if (hint != null) Text(hint, style: TextStyle(color: p.danger)),
    ]);
  }

  Widget _checkoutSection(DemoPalette p) {
    final result = _checkout.result;
    final request = _form.toRequest();
    if (result != null && request != null) {
      final needsRecovery = _demo.sdkState == OnramperStateKind.failed &&
          !_demo.hasFinalizedCheckout;
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            QuoteCard(
              quote: result.quote,
              amount: request.transactionData.amount,
              fiat: _form.fiat.name,
              cryptoSymbol: _form.crypto.symbol,
            ),
            if (needsRecovery)
              StatusBox(
                tone: StatusTone.error,
                title: 'Couldn’t start checkout',
                body: _demo.lastFailure ??
                    'Fetch a fresh quote to try checkout again.',
                actionLabel: 'Get a new quote',
                onAction: _recoverCheckout,
              )
            else
              OnramperCheckoutButton(
                key: ValueKey(result.buttonHandle),
                requirements: result,
                style: checkoutButtonStyle(p),
              ),
          ]);
    }
    if (_checkout.loading ||
        (request != null && _demo.status == InitStatus.initializing)) {
      return SizedBox(
        height: 56,
        child: Center(
          child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(p.accent)),
        ),
      );
    }
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: p.border,
          borderRadius: BorderRadius.circular(DemoRadius.button)),
      child: Text('Buy',
          style: TextStyle(
              color: p.textSecondary,
              fontSize: 17,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    final enabled = _demo.client != null;
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DemoRadius.button),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  List<Widget> _statusBoxes() {
    final pending = _demo.sdkState == OnramperStateKind.paymentPending;
    final completed = _demo.sdkState == OnramperStateKind.completed ||
        _demo.completedCheckoutId != null;
    final needsRecovery = _demo.sdkState == OnramperStateKind.failed &&
        !_demo.hasFinalizedCheckout &&
        _checkout.result != null;
    final error = _demo.initError != null
        ? ('SDK initialization failed', _demo.initError!, 'Retry', _demo.retry)
        : _checkout.error != null
            ? ('Quote failed', _checkout.error!, 'Retry', _checkout.refresh)
            : _actionError != null
                ? ('Action failed', _actionError!, null, null)
                : _demo.lastFailure != null && !needsRecovery
                    ? ('Checkout failed', _demo.lastFailure!, null, null)
                    : null;
    return [
      if (pending)
        StatusBox(
          tone: StatusTone.info,
          title: 'Payment processing',
          body:
              'Your payment was accepted and is awaiting settlement. Track it before '
              'starting another payment.\n${_demo.transactionId ?? ''}',
          selectableBody: true,
        ),
      if (completed && !pending)
        StatusBox(
          tone: StatusTone.success,
          title: 'Transaction complete',
          body: _demo.transactionId ?? _demo.completedCheckoutId,
          selectableBody: true,
        ),
      if (!completed && !pending && _demo.transactionId != null)
        StatusBox(
          tone: StatusTone.success,
          title: 'Onramper transaction ID',
          body: _demo.transactionId,
          selectableBody: true,
        ),
      if (error != null)
        StatusBox(
          tone: StatusTone.error,
          title: error.$1,
          body: error.$2,
          actionLabel: error.$3,
          onAction: error.$4,
        ),
    ];
  }
}
