import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
// ignore: implementation_imports
import 'package:super_clipboard/src/format_conversions.dart';
import 'package:super_clipboard/super_clipboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<(ClipboardDataReader, Object?)> items = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          // TODO(@HrX03) is this needed?
          // ignore: unused_local_variable
          final rawReader = item.$1.rawReader;

          return ListTile(
            title: SelectableText(item.$2.toString()),
            subtitle: SelectableText(
              item.$1.platformFormats.map((e) => "'$e'").join(', '),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Pasteboard.writeFiles(['/home/davide']);
          return;
          // TODO(@HrX03) is this needed?
          // ignore: unused_local_variable, dead_code, deprecated_member_use
          final data = await ClipboardReader.readClipboard();
          final value = await data.readValue(linuxFileUri);

          setState(() {
            items.add((data, value));
          });
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

final linuxFileUri = SimpleValueFormat(
  android: Formats.fileUri.android,
  ios: Formats.fileUri.ios,
  linux: const SimplePlatformCodec(
    formats: ['application/vnd.portal.files'],
    decodingFormats: ['application/vnd.portal.files'],
    encodingFormats: ['application/vnd.portal.files'],
    onDecode: fileUriFromString,
    onEncode: fileUriToString,
  ),
  macos: Formats.fileUri.macos,
  windows: Formats.fileUri.windows,
  web: Formats.fileUri.web,
  fallback: Formats.fileUri.fallback,
);
