part of 'generator.dart';

/// {@template hook_dependency_install_failure}
/// Thrown when an error occurs while installing hook dependencies.
/// {@endtemplate}
class HookDependencyInstallFailure extends MasonException {
  /// {@macro hook_dependency_install_failure}
  HookDependencyInstallFailure(String path, String error)
      : super(
          '''
Unable to install dependencies for hook: $path.
Error: $error''',
        );
}

/// {@template hook_invalid_characters_exception}
/// Thrown when a hook contains non-ascii characters.
/// {@endtemplate}
class HookInvalidCharactersException extends MasonException {
  /// {@macro hook_invalid_characters_exception}
  HookInvalidCharactersException(String path)
      : super(
          '''
Unable to execute hook: $path.
Error: Hook contains invalid characters.
Ensure the hook does not contain non-ascii characters.''',
        );
}

/// {@template hook_missing_run_exception}
/// Thrown when a hook does not contain a 'run' method.
/// {@endtemplate}
class HookMissingRunException extends MasonException {
  /// {@macro hook_missing_run_exception}
  HookMissingRunException(String path)
      : super(
          '''
Unable to execute hook: $path.
Error: Method 'run' not found.
Ensure the hook contains a 'run' method:

  import 'package:mason/mason.dart';

  void run(HookContext context) {...}''',
        );
}

/// {@template hook_run_exception}
/// Thrown when an error occurs when trying to run hook.
/// {@endtemplate}
class HookRunException extends MasonException {
  /// {@macro hook_run_exception}
  HookRunException(String path, String error)
      : super(
          '''
Unable to execute hook: $path.
Error: $error''',
        );
}

/// {@template hook_execution_exception}
/// Thrown when an error occurs during hook execution.
/// {@endtemplate}
class HookExecutionException extends MasonException {
  /// {@macro hook_execution_exception}
  HookExecutionException(String path, String error)
      : super(
          '''
An exception occurred while executing hook: $path.
Error: $error''',
        );
}

/// Supported types of [GeneratorHooks].
enum GeneratorHook {
  /// Hook run immediately before the `generate` method is invoked.
  preGen,

  /// Hook run immediately after the `generate` method is invoked.
  postGen,
}

/// Extension on [GeneratorHook] for converting
/// a [GeneratorHook] to the corresponding file name.
extension GeneratorHookToFileName on GeneratorHook {
  /// Converts a [GeneratorHook] to the corresponding file name.
  String toFileName() {
    switch (this) {
      case GeneratorHook.preGen:
        return 'pre_gen.dart';
      case GeneratorHook.postGen:
        return 'post_gen.dart';
    }
  }
}

/// {@template generator_hooks}
/// Scripts that run automatically whenever a particular event occurs
/// in a [Generator].
/// {@endtemplate}
class GeneratorHooks {
  /// {@macro generator_hooks}
  const GeneratorHooks({this.preGenHook, this.postGenHook, this.pubspec});

  /// Creates [GeneratorHooks] from a provided [MasonBundle].
  factory GeneratorHooks.fromBundle(MasonBundle bundle) {
    HookFile? _decodeHookFile(MasonBundledFile? file) {
      if (file == null) return null;
      final path = file.path;
      final raw = file.data.replaceAll(_whiteSpace, '');
      final decoded = base64.decode(raw);
      try {
        return HookFile.fromBytes(path, decoded);
      } catch (_) {
        return null;
      }
    }

    List<int>? _decodeHookPubspec(MasonBundledFile? file) {
      if (file == null) return null;
      final raw = file.data.replaceAll(_whiteSpace, '');
      return base64.decode(raw);
    }

    final preGen = bundle.hooks.firstWhereOrNull(
      (element) {
        return p.basename(element.path) == GeneratorHook.preGen.toFileName();
      },
    );
    final postGen = bundle.hooks.firstWhereOrNull(
      (element) {
        return p.basename(element.path) == GeneratorHook.postGen.toFileName();
      },
    );
    final pubspec = bundle.hooks.firstWhereOrNull(
      (element) {
        return p.basename(element.path) == 'pubspec.yaml';
      },
    );

    return GeneratorHooks(
      preGenHook: _decodeHookFile(preGen),
      postGenHook: _decodeHookFile(postGen),
      pubspec: _decodeHookPubspec(pubspec),
    );
  }

  /// Creates [GeneratorHooks] from a provided [BrickYaml].
  static Future<GeneratorHooks> fromBrickYaml(BrickYaml brick) async {
    Future<HookFile?> getHookFile(GeneratorHook hook) async {
      try {
        final brickRoot = File(brick.path!).parent.path;
        final hooksDirectory = Directory(p.join(brickRoot, BrickYaml.hooks));
        final file =
            hooksDirectory.listSync().whereType<File>().firstWhereOrNull(
                  (element) => p.basename(element.path) == hook.toFileName(),
                );

        if (file == null) return null;
        final content = await file.readAsBytes();
        return HookFile.fromBytes(file.path, content);
      } catch (_) {
        return null;
      }
    }

    Future<List<int>?> getHookPubspec() async {
      try {
        final brickRoot = File(brick.path!).parent.path;
        final hooksDirectory = Directory(p.join(brickRoot, BrickYaml.hooks));
        final file =
            hooksDirectory.listSync().whereType<File>().firstWhereOrNull(
                  (element) => p.basename(element.path) == 'pubspec.yaml',
                );

        if (file == null) return null;
        return await file.readAsBytes();
      } catch (_) {
        return null;
      }
    }

    return GeneratorHooks(
      preGenHook: await getHookFile(GeneratorHook.preGen),
      postGenHook: await getHookFile(GeneratorHook.postGen),
      pubspec: await getHookPubspec(),
    );
  }

  /// Hook run immediately before the `generate` method is invoked.
  final HookFile? preGenHook;

  /// Hook run immediately after the `generate` method is invoked.
  final HookFile? postGenHook;

  /// Contents of the hooks `pubspec.yaml` if exists.
  final List<int>? pubspec;

  /// Runs the pre-generation (pre_gen) hook with the specified [vars].
  /// An optional [workingDirectory] can also be specified.
  Future<void> preGen({
    Map<String, dynamic> vars = const <String, dynamic>{},
    String? workingDirectory,
    void Function(Map<String, dynamic> vars)? onVarsChanged,
  }) async {
    final preGenHook = this.preGenHook;
    if (preGenHook != null && pubspec != null) {
      return _runHook(
        hook: preGenHook,
        vars: vars,
        workingDirectory: workingDirectory,
        onVarsChanged: onVarsChanged,
      );
    }
  }

  /// Runs the post-generation (post_gen) hook with the specified [vars].
  /// An optional [workingDirectory] can also be specified.
  Future<void> postGen({
    Map<String, dynamic> vars = const <String, dynamic>{},
    String? workingDirectory,
    void Function(Map<String, dynamic> vars)? onVarsChanged,
  }) async {
    final postGenHook = this.postGenHook;
    if (postGenHook != null && pubspec != null) {
      return _runHook(
        hook: postGenHook,
        vars: vars,
        workingDirectory: workingDirectory,
        onVarsChanged: onVarsChanged,
      );
    }
  }

  /// Runs the provided [hook] with the specified [vars].
  /// An optional [workingDirectory] can also be specified.
  Future<void> _runHook({
    required HookFile hook,
    Map<String, dynamic> vars = const <String, dynamic>{},
    void Function(Map<String, dynamic> vars)? onVarsChanged,
    String? workingDirectory,
  }) async {
    final pubspec = this.pubspec;
    final subscriptions = <StreamSubscription>[];
    final messagePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    dynamic hookError;
    subscriptions.add(errorPort.listen((dynamic error) => hookError = error));

    if (onVarsChanged != null) {
      subscriptions.add(
        messagePort.listen((dynamic message) {
          if (message is String) {
            onVarsChanged(
              json.decode(message) as Map<String, dynamic>,
            );
          }
        }),
      );
    }

    Uri? packageConfigUri;
    if (pubspec != null) {
      final directoryHash = sha1.convert(pubspec).toString();
      final directory = Directory(
        p.join(Directory.systemTemp.path, '.mason', directoryHash),
      );
      final packageConfigFile = File(
        p.join(directory.path, '.dart_tool', 'package_config.json'),
      );

      if (!packageConfigFile.existsSync()) {
        await directory.create(recursive: true);
        await File(
          p.join(directory.path, 'pubspec.yaml'),
        ).writeAsBytes(pubspec);

        final result = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: directory.path,
          runInShell: true,
        );

        if (result.exitCode != 0) {
          throw HookDependencyInstallFailure(hook.path, '${result.stderr}');
        }
      }

      final packageConfigBytes = await packageConfigFile.readAsBytes();
      packageConfigUri = Uri.dataFromBytes(packageConfigBytes);
    }

    Uri? uri;
    try {
      uri = _getHookUri(hook.runSubstitution(vars).content);
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw HookInvalidCharactersException(hook.path);
    }

    if (uri == null) throw HookMissingRunException(hook.path);

    final cwd = Directory.current;
    Isolate? isolate;
    try {
      if (workingDirectory != null) Directory.current = workingDirectory;
      isolate = await Isolate.spawnUri(
        uri,
        [json.encode(vars)],
        messagePort.sendPort,
        paused: true,
        packageConfig: packageConfigUri,
      );
    } on IsolateSpawnException catch (error) {
      Directory.current = cwd;
      final msg = error.message;
      final content = msg.contains('Error: ') ? msg.split('Error: ').last : msg;
      throw HookRunException(hook.path, content.trim());
    }

    isolate
      ..addErrorListener(errorPort.sendPort)
      ..addOnExitListener(exitPort.sendPort)
      ..resume(isolate.pauseCapability!);

    try {
      await exitPort.first;
    } finally {
      Directory.current = cwd;
    }

    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }

    if (hookError != null) {
      final dynamic error = hookError;
      final content =
          error is List && error.isNotEmpty ? '${error.first}' : '$error';
      throw HookExecutionException(hook.path, content);
    }
  }
}

/// {@template hook_file}
/// This class represents a hook file in a generator.
/// The contents should be text and may contain mustache.
/// {@endtemplate}
class HookFile {
  /// {@macro hook_file}
  HookFile.fromBytes(this.path, this.content);

  /// The template file path.
  final String path;

  /// The template file content.
  final List<int> content;

  /// Performs a substitution on the [path] based on the incoming [parameters].
  FileContents runSubstitution(Map<String, dynamic> parameters) {
    return FileContents(path, _createContent(parameters));
  }

  List<int> _createContent(Map<String, dynamic> vars) {
    try {
      final decoded = utf8.decode(content);
      if (!decoded.contains(_delimeterRegExp)) return content;
      final rendered = decoded.render(vars);
      return utf8.encode(rendered);
    } on Exception {
      return content;
    }
  }
}

/// A reference to core mason APIs to be used within hooks.
///
/// Each hook is defined as a `run` method which accepts a
/// [HookContext] instance.
///
/// [HookContext] exposes APIs to:
/// * read/write template vars
/// * access a [Logger] instance
///
/// ```dart
/// // pre_gen.dart
/// import 'package:mason/mason.dart';
///
/// void run(HookContext context) {
///   // Read/Write vars
///   context.vars = {...context.vars, 'custom_var': 'foo'};
///
///   // Use the logger
///   context.logger.info('hello from pre_gen.dart');
/// }
/// ```
abstract class HookContext {
  /// Getter that returns the current map of variables.
  Map<String, dynamic> get vars;

  /// Setter that enables updating the current map of variables.
  set vars(Map<String, dynamic> value);

  /// Getter that returns a [Logger] instance.
  Logger get logger;
}

final _runRegExp = RegExp(
  r'((void||Future<void>)\srun\(HookContext)',
  multiLine: true,
);

Uri? _getHookUri(List<int> content) {
  final decoded = utf8.decode(content);
  if (_runRegExp.hasMatch(decoded)) {
    final code = _generatedHookCode(decoded);
    return Uri.dataFromString(code, mimeType: 'application/dart');
  }
  return null;
}

String _generatedHookCode(String content) => '''
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'dart:convert';
import 'dart:isolate';

$content

void main(List<String> args, SendPort port) {
  run(_HookContext._(port, vars: json.decode(args.first)));
}

class _HookContext implements HookContext {
  _HookContext._(
    this._port, {
    Map<String, dynamic>? vars,
  }) : _vars = vars ?? <String, dynamic>{};

  final SendPort _port;
  Map<String, dynamic> _vars;

  @override
  Map<String, dynamic> get vars => _vars;

  @override
  final logger = Logger();

  @override
  set vars(Map<String, dynamic> value) {
    _vars = value;
    _port.send(json.encode(_vars));
  }
}
''';
