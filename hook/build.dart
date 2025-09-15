import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final targetOS = input.config.code.targetOS;
    if (targetOS != OS.linux) return;

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'libfs.dart',
        linkMode: DynamicLoadingSystem(Uri.file('src/zig-out/lib/libfs.so')),
      ),
    );
  });
}
