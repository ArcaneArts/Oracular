import 'package:arcane_beamer/screens/example_screen.dart';
import 'package:arcane_beamer/screens/home_screen.dart';
import 'package:arcane_beamer/screens/not_found_screen.dart';
import 'package:arcane/arcane.dart';
import 'package:beamer/beamer.dart';

BuildContext? globalContext;

typedef BeamerRouteBuilder = dynamic Function(
    BuildContext, BeamState, Object?);

/// Helper to create a simple route with a static screen
MapEntry<Pattern, BeamerRouteBuilder> route(
        String path, String title, Widget screen) =>
    MapEntry(
      path,
      (context, state, data) => BeamPage(
        key: ValueKey("beamer.$path"),
        child: screen,
        title: title,
      ),
    );

/// The main router delegate for Beamer
final BeamerDelegate routerDelegate = BeamerDelegate(
  initialPath: "/",
  notFoundRedirectNamed: "/404",
  buildListener: (context, router) => globalContext = context,
  locationBuilder: RoutesLocationBuilder(
    routes: Map.fromEntries([
      // Main routes
      route("/", "Home - Arcane Beamer", const HomeScreen()),
      route("/example", "Example Page", const ExampleScreen()),

      // System routes
      route("/404", "404 - Not Found", const NotFoundScreen()),
    ]),
  ).call,
);
