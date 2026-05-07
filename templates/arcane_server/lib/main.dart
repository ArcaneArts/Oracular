import 'dart:async';
import 'dart:io';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:fast_log/fast_log.dart';
import 'package:google_cloud/google_cloud.dart';
import 'package:arcane_models/arcane_models.dart';
import 'package:arcane_server/api/user_api.dart';
import 'package:arcane_server/api/settings_api.dart';
import 'package:arcane_server/api/command_api.dart';
import 'package:arcane_server/service/user_service.dart';
import 'package:arcane_server/service/command_service.dart';
import 'package:arcane_server/service/media_service.dart';
import 'package:arcane_server/util/request_authenticator.dart';
import 'package:ostrich/ostrich.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

class ArcaneServer implements Routing {
  static late final ArcaneServer instance;
  late final HttpServer server;
  late final RequestAuthenticator authenticator;

  // Services
  static late UserService svcUser;
  static late CommandService svcCommand;
  static late MediaService svcMedia;

  // APIs
  static late UserAPI apiUser;
  static late SettingsAPI apiSettings;
  static late CommandAPI apiCommand;

  Future<void> start() async {
    registerCrud();
    await ArcaneAdmin.initialize();
    instance = this;
    await Future.wait([_startServices(), _startAPIs()]);

    FirestoreDatabase.instance.debugLogging = false;

    authenticator = RequestAuthenticator();

    // Start Server
    verbose("STARTING arcane_server");
    server = await serve(_pipeline, InternetAddress.anyIPv4, listenPortFromEnvironment());
    verbose("Server listening on port ${server.port}");
  }

  Future<void> _startServices() async {
    svcUser = UserService();
    svcCommand = CommandService();
    svcMedia = MediaService();
    verbose("Services Online");
  }

  Future<void> _startAPIs() async {
    apiUser = UserAPI();
    apiSettings = SettingsAPI();
    apiCommand = CommandAPI();
    verbose("APIs Initialized");
  }

  Future<Response> _onError(Object err, StackTrace stackTrace) async {
    error('Request Error: $err');
    error('Stack Trace: $stackTrace');
    return Response.internalServerError();
  }

  Future<Response?> _onRequest(Request request) =>
      authenticator.authenticateRequest(request);

  Future<Response> _onResponse(Response response) async {
    return response;
  }

  Handler get _pipeline => Pipeline()
      .addMiddleware(_corsMiddleware)
      .addMiddleware(_middleware)
      .addHandler(router.call);

  @override
  String get prefix => "/";

  Middleware get _middleware => createMiddleware(
    requestHandler: _onRequest,
    errorHandler: _onError,
    responseHandler: _onResponse,
  );

  Middleware get _corsMiddleware => corsHeaders(
    headers: {
      ACCESS_CONTROL_ALLOW_ORIGIN: "*",
      ACCESS_CONTROL_ALLOW_METHODS: "GET, POST, PUT, DELETE, OPTIONS",
      ACCESS_CONTROL_ALLOW_HEADERS: "*",
    },
  );

  @override
  Router get router => Router()
    ..mount(apiUser.prefix, apiUser.router.call)
    ..mount(apiSettings.prefix, apiSettings.router.call)
    ..mount(apiCommand.prefix, apiCommand.router.call)
    ..get("/keepAlive", _requestGetKeepAlive);

  Future<Response> _requestGetKeepAlive(Request request) async =>
      Response.ok('{"ok": true}');
}

// Firebase Storage bucket name (update with your project ID)
const String bucket = "FIREBASE_PROJECT_ID.firebasestorage.app";

abstract class Routing {
  Router get router;
  String get prefix;
}

extension XRequest on Request {
  String? param(String key) => url.queryParameters[key];
}

void main() => runFlutterServer((context) => ArcaneServer().start());
