// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:arcane_jaspr/component/collection/card_carousel.dart'
    as _card_carousel;
import 'package:arcane_jaspr/component/collection/infinite_carousel.dart'
    as _infinite_carousel;
import 'package:arcane_jaspr/component/dialog/dialog.dart' as _dialog;
import 'package:arcane_jaspr/component/dialog/text.dart' as _text;
import 'package:arcane_jaspr/component/dialog/toast.dart' as _toast;
import 'package:arcane_jaspr/component/feedback/alert_banner.dart'
    as _alert_banner;
import 'package:arcane_jaspr/component/feedback/loader.dart' as _loader;
import 'package:arcane_jaspr/component/feedback/tooltip.dart' as _tooltip;
import 'package:arcane_jaspr/component/form/field.dart' as _field;
import 'package:arcane_jaspr/component/form/field_wrapper.dart'
    as _field_wrapper;
import 'package:arcane_jaspr/component/form/newsletter_form.dart'
    as _newsletter_form;
import 'package:arcane_jaspr/component/input/text_input.dart' as _text_input;
import 'package:arcane_jaspr/component/interactive/accordion.dart'
    as _accordion;
import 'package:arcane_jaspr/component/interactive/back_to_top.dart'
    as _back_to_top;
import 'package:arcane_jaspr/component/layout/auth_layout.dart' as _auth_layout;
import 'package:arcane_jaspr/component/layout/dashboard_layout.dart'
    as _dashboard_layout;
import 'package:arcane_jaspr/component/layout/footer.dart' as _footer;
import 'package:arcane_jaspr/component/layout/logo_carousel.dart'
    as _logo_carousel;
import 'package:arcane_jaspr/component/navigation/bottom_navigation_bar.dart'
    as _bottom_navigation_bar;
import 'package:arcane_jaspr/component/navigation/dropdown_menu.dart'
    as _dropdown_menu;
import 'package:arcane_jaspr/component/navigation/header.dart' as _header;
import 'package:arcane_jaspr/component/navigation/mobile_menu.dart'
    as _mobile_menu;
import 'package:arcane_jaspr/component/navigation/sidebar.dart' as _sidebar;
import 'package:arcane_jaspr/component/screen/navigation_screen.dart'
    as _navigation_screen;
import 'package:arcane_jaspr/component/screen/screen.dart' as _screen;
import 'package:arcane_jaspr/component/support/app.dart' as _app;
import 'package:arcane_jaspr/component/view/bar.dart' as _bar;
import 'package:arcane_jaspr/component/view/card.dart' as _card;
import 'package:arcane_jaspr/component/view/center_body.dart' as _center_body;
import 'package:arcane_jaspr/component/view/code_snippet.dart' as _code_snippet;
import 'package:arcane_jaspr/component/view/data_table.dart' as _data_table;
import 'package:arcane_jaspr/component/view/expander.dart' as _expander;
import 'package:arcane_jaspr/component/view/feature_card.dart' as _feature_card;
import 'package:arcane_jaspr/component/view/game_tile.dart' as _game_tile;
import 'package:arcane_jaspr/component/view/glass.dart' as _glass;
import 'package:arcane_jaspr/component/view/gradient_text.dart'
    as _gradient_text;
import 'package:arcane_jaspr/component/view/integration_card.dart'
    as _integration_card;
import 'package:arcane_jaspr/component/view/pricing_card.dart' as _pricing_card;
import 'package:arcane_jaspr/component/view/skeleton.dart' as _skeleton;
import 'package:arcane_jaspr/component/view/social_icons.dart' as _social_icons;
import 'package:arcane_jaspr/component/view/tile.dart' as _tile;

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

  styles: () => [
    ..._card_carousel.ArcaneCardCarousel.styles,
    ..._card_carousel.ArcaneHeroCarousel.styles,
    ..._card_carousel.ArcaneNavigableCarousel.styles,
    ..._infinite_carousel.ArcaneInfiniteCarousel.styles,
    ..._dialog.ArcaneDialog.styles,
    ..._dialog.ArcaneSheet.styles,
    ..._text.ArcaneTextInputDialog.styles,
    ..._toast.ArcaneToast.styles,
    ..._alert_banner.ArcaneLoader.styles,
    ..._alert_banner.ArcaneProgressBar.styles,
    ..._loader.ArcaneDotsLoader.styles,
    ..._loader.ArcaneLoader.styles,
    ..._loader.ArcanePulseLoader.styles,
    ..._tooltip.ArcaneInfoTooltip.styles,
    ..._tooltip.ArcaneTooltip.styles,
    ..._field.ArcaneFieldStyles.styles,
    ..._field_wrapper.ArcaneForm.styles,
    ..._newsletter_form.ArcaneNewsletterForm.styles,
    ..._text_input.ArcaneSelect.styles,
    ..._text_input.ArcaneTextArea.styles,
    ..._text_input.ArcaneTextInput.styles,
    ..._accordion.ArcaneAccordion.styles,
    ..._back_to_top.ArcaneBackToTop.styles,
    ..._back_to_top.ArcaneFloatingActionButton.styles,
    ..._auth_layout.ArcaneAuthBackLink.styles,
    ..._dashboard_layout.ArcaneDashboardLayout.styles,
    ..._dashboard_layout.ArcaneDashboardUserMenu.styles,
    ..._footer.ArcaneFooter.styles,
    ..._footer.ArcaneSocialIcon.styles,
    ..._logo_carousel.ArcaneLogoCarousel.styles,
    ..._logo_carousel.ArcaneLogoGrid.styles,
    ..._bottom_navigation_bar.ArcaneBottomNavigationBar.styles,
    ..._dropdown_menu.ArcaneDropdownMenu.styles,
    ..._dropdown_menu.ArcaneMegaMenu.styles,
    ..._header.ArcaneHeader.styles,
    ..._header.ArcaneNavLink.styles,
    ..._mobile_menu.ArcaneMobileMenu.styles,
    ..._sidebar.ArcaneSidebar.styles,
    ..._sidebar.ArcaneSidebarItem.styles,
    ..._navigation_screen.ArcaneResponsiveScaffold.styles,
    ..._screen.ArcaneScreen.styles,
    ..._app.ArcaneApp.styles,
    ..._bar.ArcaneBar.styles,
    ..._card.ArcaneCard.styles,
    ..._card.ArcaneImageCard.styles,
    ..._center_body.ArcaneLoadingState.styles,
    ..._code_snippet.ArcaneCodeSnippet.styles,
    ..._code_snippet.ArcaneTerminal.styles,
    ..._data_table.ArcaneDataTable.styles,
    ..._expander.ArcaneExpander.styles,
    ..._feature_card.ArcaneFeatureCard.styles,
    ..._feature_card.ArcaneIconCard.styles,
    ..._game_tile.ArcaneGameCard.styles,
    ..._game_tile.ArcaneGameTile.styles,
    ..._glass.ArcaneGlassCard.styles,
    ..._gradient_text.ArcaneAnimatedGradientText.styles,
    ..._integration_card.ArcaneIntegrationCard.styles,
    ..._pricing_card.ArcanePricingCard.styles,
    ..._skeleton.ArcaneSkeleton.styles,
    ..._social_icons.ArcaneSocialIcon.styles,
    ..._social_icons.ArcaneSocialLinks.styles,
    ..._tile.ArcaneNavTile.styles,
    ..._tile.ArcaneTile.styles,
  ],
);
