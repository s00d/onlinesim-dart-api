// Analyzes the code examples of README.md, docs/content/*.md and
// example/main.dart against lib/, so the docs cannot drift from the API.
// A ```dart block counts as an example when it has a `;`; the others are
// signatures. An example without `main(` is wrapped in a function whose
// parameters supply an undeclared `client`, `tzid` or `mock`.
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:test/test.dart';

final _block = RegExp(r'```dart[^\n]*\n([\s\S]*?)```');

Map<String, String> _examples() {
  final sources = [
    'README.md',
    for (final f
        in Directory('docs/content').listSync()
          ..sort((a, b) => a.path.compareTo(b.path)))
      if (f.path.endsWith('.md')) f.path,
  ];
  final files = <String, String>{};
  for (final source in sources) {
    var i = 0;
    for (final m in _block.allMatches(File(source).readAsStringSync())) {
      final code = m[1]!;
      if (!code.contains(';')) continue;
      final name =
          '${source.replaceAll(RegExp(r'\W'), '_').toLowerCase()}_${i++}.dart';
      files[name] = _wrap(code);
    }
  }
  return files;
}

String _wrap(String code) {
  final lines = code.split('\n');
  final imports = lines.where((l) => l.startsWith('import ')).toSet();
  final body = lines.where((l) => !l.startsWith('import ')).join('\n');
  imports.add("import 'package:onlinesim/onlinesim.dart';");
  if (body.contains('main(')) return '${imports.join('\n')}\n$body\n';
  bool declared(String name) =>
      RegExp('(final|var|late|[A-Z]\\w*\\??)\\s+$name\\b').hasMatch(body);
  final params = [
    if (RegExp(r'\bclient\b').hasMatch(body) && !declared('client'))
      'OnlineSim client',
    if (RegExp(r'\btzid\b').hasMatch(body) && !declared('tzid')) 'int tzid',
    if (RegExp(r'\bmock\b').hasMatch(body) && !declared('mock'))
      'MockOnlineSim mock',
  ];
  return '${imports.join('\n')}\n\n'
      'Future<void> example(${params.join(', ')}) async {\n$body\n}\n';
}

void main() {
  test('docs examples analyze cleanly against the SDK', () async {
    final files = _examples();
    expect(files.length, greaterThan(25));

    final dir = Directory('.dart_tool/docs_examples');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    // Snippets assign results they do not use and declare helpers they do not
    // call; everything else follows the package's own analysis options.
    File('${dir.path}/analysis_options.yaml').writeAsStringSync('''
include: ../../analysis_options.yaml
analyzer:
  errors:
    unused_local_variable: ignore
    unused_element: ignore
linter:
  rules:
    public_member_api_docs: false
''');
    files.forEach((name, text) {
      File('${dir.path}/$name').writeAsStringSync(text);
    });
    File('example/main.dart').copySync('${dir.path}/example_main.dart');

    final result = await Process.run(
      Platform.resolvedExecutable,
      ['analyze', '--fatal-infos', dir.path],
    );
    final output = '${result.stdout}${result.stderr}';
    expect(result.exitCode, 0, reason: output);
  });
}
