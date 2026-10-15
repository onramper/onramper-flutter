import 'package:flutter/material.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

class PrefillController {
  final email = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();

  /// Null when every field is blank, so no prefill is sent.
  OnramperUserPrefill? build() {
    String? v(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final p = OnramperUserPrefill(
      email: v(email),
      firstName: v(firstName),
      lastName: v(lastName),
      phoneNumber: v(phone),
    );
    return p.toDto() == null ? null : p;
  }

  void dispose() {
    email.dispose();
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
  }
}

/// Collapsible prefill inputs passed to `getCheckoutRequirements(prefill:)`.
class PrefillForm extends StatelessWidget {
  const PrefillForm({super.key, required this.controller});

  final PrefillController controller;

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, [String? helper]) => InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          isDense: true,
        );
    return ExpansionTile(
      title: const Text('Prefill (optional)'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        TextField(
          controller: controller.email,
          keyboardType: TextInputType.emailAddress,
          decoration: deco('Email',
              'Must match the OnramperID sign-in email, or all prefill is dropped.'),
        ),
        TextField(
            controller: controller.firstName, decoration: deco('First name')),
        TextField(
            controller: controller.lastName, decoration: deco('Last name')),
        TextField(
          controller: controller.phone,
          keyboardType: TextInputType.phone,
          decoration: deco('Phone', 'E.164, e.g. +3712345678'),
        ),
      ],
    );
  }
}
