// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:arcane_jaspr/component/collection/card_carousel.dart'
    as _card_carousel;
import 'package:arcane_jaspr/component/collection/infinite_carousel.dart'
    as _infinite_carousel;
import 'package:arcane_jaspr/component/form/field.dart' as _field;
import 'package:arcane_jaspr/component/view/avatar.dart' as _avatar;
import 'package:jaspr_content/components/_internal/tab_bar.dart' as _tab_bar;
import 'package:jaspr_content/components/tabs.dart' as _tabs;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _tab_bar.TabBar: ClientTarget<_tab_bar.TabBar>(
      'jaspr_content:tab_bar',
      params: __tab_barTabBar,
    ),
  },
  styles: () => [
    ..._card_carousel.ArcaneCardCarousel.styles,
    ..._card_carousel.ArcaneHeroCarousel.styles,
    ..._card_carousel.ArcaneNavigableCarousel.styles,
    ..._infinite_carousel.ArcaneInfiniteCarousel.styles,
    ..._field.ArcaneFieldStyles.styles,
    ..._avatar.ArcaneAvatarBadge.styles,
    ..._tab_bar.TabBar.styles,
    ..._tabs.Tabs.styles,
  ],
);

Map<String, Object?> __tab_barTabBar(_tab_bar.TabBar c) => {
  'initialValue': c.initialValue,
  'items': c.items,
};
