import 'package:flutter/material.dart';

import '../checkout/prefill.dart';
import '../theme/demo_theme.dart';
import 'demo_card.dart';
import 'demo_field.dart';
import 'switch_row.dart';

/// RN `PrefillCard`: collapsed by default; header shows what would be sent.
class PrefillCard extends StatefulWidget {
  const PrefillCard({super.key, required this.value, required this.onChanged});

  final PrefillInput value;
  final ValueChanged<PrefillInput> onChanged;

  @override
  State<PrefillCard> createState() => _PrefillCardState();
}

class _PrefillCardState extends State<PrefillCard> {
  bool _open = false;
  late final _first = TextEditingController(text: widget.value.firstName);
  late final _last = TextEditingController(text: widget.value.lastName);
  late final _phone = TextEditingController(text: widget.value.phoneNumber);
  late final _email = TextEditingController(text: widget.value.email);

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _set(PrefillInput next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final v = widget.value;
    final note = TextStyle(color: p.textSecondary, fontSize: 12, height: 16 / 12);
    return DemoCard(children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: Row(children: [
          Expanded(
            child: Text('Prefill',
                style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ),
          Text('${prefillSummary(v)} ${_open ? '▾' : '▸'}',
              style: TextStyle(color: p.textSecondary, fontSize: 12)),
        ]),
      ),
      if (_open)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
          SwitchRow(
            label: 'Send prefill',
            value: v.enabled,
            onChanged: (x) => _set(v.copyWith(enabled: x)),
          ),
          Text(
            'Pre-populates the OnramperID sign-in and additional-info screens. '
            "Best-effort: if it can't be applied, sign-in opens normally. "
            'A prefilled phone is still verified by the user.',
            style: note,
          ),
          DemoField(
            label: 'First name',
            controller: _first,
            enabled: v.enabled,
            onChanged: (x) => _set(widget.value.copyWith(firstName: x)),
          ),
          DemoField(
            label: 'Last name',
            controller: _last,
            enabled: v.enabled,
            onChanged: (x) => _set(widget.value.copyWith(lastName: x)),
          ),
          DemoField(
            label: 'Phone (E.164)',
            controller: _phone,
            placeholder: '+3712345678',
            keyboardType: TextInputType.phone,
            enabled: v.enabled,
            onChanged: (x) => _set(widget.value.copyWith(phoneNumber: x)),
          ),
          SwitchRow(
            label: 'Send email',
            value: v.sendEmail,
            disabled: !v.enabled,
            onChanged: (x) => _set(v.copyWith(sendEmail: x)),
          ),
          DemoField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            enabled: v.enabled && v.sendEmail,
            onChanged: (x) => _set(widget.value.copyWith(email: x)),
          ),
          Text(
            "Email identifies which account the other values belong to. If it doesn't "
            'match the account that signs in, the whole prefill is dropped — only send '
            "it if you're sure.",
            style: note.copyWith(color: p.warning),
          ),
        ]),
    ]);
  }
}
