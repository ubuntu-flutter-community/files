/*
Copyright 2019 The dahliaOS Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:files/backend/providers.dart';
import 'package:files/backend/workspace.dart';
import 'package:files/widgets/side_pane.dart';
import 'package:files/widgets/tab_strip.dart';
import 'package:files/widgets/workspace.dart';
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await YaruWindowTitleBar.ensureInitialized();
  await YaruWindow.ensureInitialized();
  await initProviders();
  await driveProvider.init();

  final initialDir = args.isNotEmpty ? args.first : null;

  runApp(Files(initialDir: initialDir));
}

ThemeData? _applyThemeValues(ThemeData? theme) {
  return theme?.copyWith(
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: theme.outlinedButtonTheme.style?.merge(
        OutlinedButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    ),
  );
}

class Files extends StatelessWidget {
  const Files({this.initialDir, super.key});
  final String? initialDir;

  @override
  Widget build(BuildContext context) {
    return YaruTheme(
      builder: (context, value, child) {
        return MaterialApp(
          title: 'Files',
          theme: _applyThemeValues(value.theme),
          darkTheme: _applyThemeValues(value.darkTheme),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          debugShowCheckedModeBanner: false,
          home: FilesHome(initialDir: initialDir),
        );
      },
    );
  }
}

class FilesHome extends StatefulWidget {
  const FilesHome({this.initialDir, super.key});
  final String? initialDir;

  @override
  State<FilesHome> createState() => _FilesHomeState();
}

class _FilesHomeState extends State<FilesHome> {
  late final List<WorkspaceController> workspaces = [
    WorkspaceController(
      initialDir: widget.initialDir ?? folderProvider.destinations.first.path,
    ),
  ];
  int currentWorkspace = 0;

  String get currentDir => workspaces[currentWorkspace].currentDir;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          GestureDetector(
            onPanStart: (details) => YaruWindow.drag(context),
            onSecondaryTap: () => YaruWindow.showMenu(context),
            child: SizedBox(
              height: 56,
              child: TabStrip(
                tabs: workspaces,
                selectedTab: currentWorkspace,
                allowClosing: workspaces.length > 1,
                onTabChanged: (index) =>
                    setState(() => currentWorkspace = index),
                onTabClosed: (index) {
                  workspaces.removeAt(index);
                  if (index < workspaces.length) {
                    currentWorkspace = index;
                  } else if (index - 1 >= 0) {
                    currentWorkspace = index - 1;
                  }
                  setState(() {});
                },
                onNewTab: () {
                  workspaces.add(WorkspaceController(initialDir: currentDir));
                  currentWorkspace = workspaces.length - 1;
                  setState(() {});
                },
                trailing: [
                  const SizedBox(width: 16),
                  YaruWindowControl(
                    type: YaruWindowControlType.minimize,
                    onTap: () => YaruWindow.minimize(context),
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<YaruWindowState>(
                    stream: YaruWindow.states(context),
                    builder: (context, snapshot) {
                      final maximized = snapshot.data?.isMaximized ?? false;

                      return YaruWindowControl(
                        type: maximized
                            ? YaruWindowControlType.restore
                            : YaruWindowControlType.maximize,
                        onTap: () => maximized
                            ? YaruWindow.restore(context)
                            : YaruWindow.maximize(context),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  YaruWindowControl(
                    type: YaruWindowControlType.close,
                    onTap: () => YaruWindow.close(context),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          const Divider(thickness: 1, height: 1),
          Expanded(
            child: Row(
              children: [
                SidePane(
                  destinations: folderProvider.destinations,
                  workspace: workspaces[currentWorkspace],
                  onNewTab: (tabPath) {
                    workspaces.add(WorkspaceController(initialDir: tabPath));
                    currentWorkspace = workspaces.length - 1;
                    setState(() {});
                  },
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: FilesWorkspace(
                    key: ValueKey(currentWorkspace),
                    controller: workspaces[currentWorkspace],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
