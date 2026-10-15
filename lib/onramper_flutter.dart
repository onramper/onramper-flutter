/// Public Dart API for the OnramperSDK Flutter plugin.
///
/// Exports the idiomatic Dart wrappers around the Pigeon-generated DTOs
/// (`lib/src/platform/pigeon.g.dart`) plus the top-level [OnramperClient]
/// facade and the checkout button widget.
library onramper_flutter;

export 'src/models/configuration.dart';
export 'src/models/errors.dart';
export 'src/models/events.dart';
export 'src/models/log_record.dart';
export 'src/models/prefill.dart';
export 'src/models/provider_json.dart';
export 'src/models/quote.dart';
export 'src/models/requirements.dart';
export 'src/models/state.dart';
export 'src/onramper_client.dart' show OnramperClient, SessionExpirationHandler;
export 'src/widget/checkout_button.dart';
export 'src/widget/checkout_button_style.dart';
export 'src/widget/native_checkout_button.dart';
