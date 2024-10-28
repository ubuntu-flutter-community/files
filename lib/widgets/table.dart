import 'dart:io';

import 'package:collection/collection.dart';
import 'package:files/backend/entity_info.dart';
import 'package:files/backend/utils.dart';
import 'package:files/backend/workspace.dart';
import 'package:files/widgets/double_scrollbars.dart';
import 'package:files/widgets/entity_context_menu.dart';
import 'package:files/widgets/timed_inkwell.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
// ignore: implementation_imports
import 'package:super_clipboard/src/format_conversions.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:yaru/yaru.dart';

typedef HeaderTapCallback = void Function(
  bool newAscending,
  int newColumnIndex,
);

typedef HeaderResizeCallback = void Function(
  int newColumnIndex,
  DragUpdateDetails details,
);

class FilesTable extends StatelessWidget {
  final List<FilesRow> rows;
  final List<FilesColumn> columns;
  final double rowHeight;
  final double rowHorizontalPadding;
  final bool ascending;
  final int columnIndex;
  final HeaderTapCallback? onHeaderCellTap;
  final HeaderResizeCallback? onHeaderResize;
  final ScrollController horizontalController;
  final ScrollController verticalController;

  const FilesTable({
    required this.rows,
    required this.columns,
    this.rowHeight = 32,
    this.rowHorizontalPadding = 8,
    this.ascending = false,
    this.columnIndex = 0,
    this.onHeaderCellTap,
    this.onHeaderResize,
    required this.horizontalController,
    required this.verticalController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final WorkspaceController controller = WorkspaceController.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () => controller.clearSelectedItems(),
          child: DoubleScrollbars(
            horizontalController: horizontalController,
            verticalController: verticalController,
            child: ScrollProxy(
              direction: Axis.horizontal,
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                child: ScrollProxy(
                  direction: Axis.vertical,
                  child: SizedBox(
                    height: constraints.maxHeight,
                    width: layoutWidth + rowHorizontalPadding * 2,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ListView.builder(
                            itemBuilder: _buildRow,
                            padding: const EdgeInsets.only(top: 36),
                            itemCount: rows.length,
                            controller: verticalController,
                          ),
                        ),
                        _buildHeaderRow(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double get layoutWidth => columns.map((e) => e.normalizedWidth).sum;

  Widget _buildHeaderRow(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...columns.mapIndexed(
              (index, column) => _buildHeaderCell(
                column,
                index,
              ),
            ),
            Container(
              width: rowHorizontalPadding,
              color: Theme.of(context).colorScheme.surface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final row = rows[index];

    return Draggable<FileSystemEntity>(
      childWhenDragging: _FilesRow(
        row: row,
        columns: columns,
        horizontalPadding: rowHorizontalPadding,
        size: Size(
          layoutWidth + (rowHorizontalPadding * 2),
          rowHeight,
        ),
      ),
      data: row.entity.entity,
      dragAnchorStrategy: (draggable, context, position) {
        return const Offset(32, 32);
      },
      feedback: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        child: Icon(
          row.entity.isDirectory
              ? Utils.iconForFolder(row.entity.path)
              : Utils.iconForPath(row.entity.path),
          color: row.entity.isDirectory
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          size: 64,
        ),
      ),
      child: _FilesRow(
        row: row,
        columns: columns,
        horizontalPadding: rowHorizontalPadding,
        size: Size(
          layoutWidth + (rowHorizontalPadding * 2),
          rowHeight,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(FilesColumn column, int index) {
    final double startPadding = index == 0 ? rowHorizontalPadding : 0;

    return InkWell(
      onTap: column.allowSorting
          ? () {
              bool newAscending = ascending;
              if (columnIndex == index) {
                newAscending = !newAscending;
              }

              onHeaderCellTap?.call(newAscending, index);
            }
          : null,
      child: Container(
        width: column.normalizedWidth + startPadding,
        constraints: BoxConstraints(minWidth: startPadding + 80),
        padding: EdgeInsetsDirectional.only(
          start: startPadding,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: index == 0 ? rowHorizontalPadding : 8,
                  end: 8,
                ),
                child: SizedBox.expand(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.type.formattedName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (columnIndex == index)
                        Icon(
                          ascending ? YaruIcons.go_down : YaruIcons.go_up,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: -3,
              top: 0,
              bottom: 0,
              width: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                opaque: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    onHeaderResize?.call(index, details);
                  },
                  child: const VerticalDivider(width: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilesColumn {
  final double width;
  final FilesColumnType type;
  final bool allowSorting;

  double get normalizedWidth => width.clamp(80, double.infinity);

  const FilesColumn({
    required this.width,
    required this.type,
    this.allowSorting = true,
  });
}

enum FilesColumnType {
  name,
  date,
  type,
  size;

  String get formattedName => this.name.sentenceCase;
}

class FilesRow {
  final EntityInfo entity;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongTap;
  final VoidCallback? onSecondaryTap;

  const FilesRow({
    required this.entity,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongTap,
    this.onSecondaryTap,
  });
}

class _FilesRow extends StatefulWidget {
  final FilesRow row;
  final List<FilesColumn> columns;
  final Size size;
  final double horizontalPadding;

  const _FilesRow({
    required this.row,
    required this.columns,
    required this.size,
    required this.horizontalPadding,
  });

  @override
  _FilesRowState createState() => _FilesRowState();
}

class _FilesRowState extends State<_FilesRow> {
  @override
  void initState() {
    super.initState();
    widget.row.entity.stat.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<FileSystemEntity>(
      onWillAcceptWithDetails: (details) {
        if (!widget.row.entity.isDirectory) return false;

        if (details.data.path == widget.row.entity.path) return false;

        return true;
      },
      onAcceptWithDetails: (details) =>
          Utils.moveFileToDest(details.data, widget.row.entity.path),
      builder: (context, candidateData, rejectedData) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              constraints:
                  BoxConstraints.tightForFinite(height: widget.size.height),
              padding: EdgeInsetsDirectional.only(
                end: (constraints.maxWidth - widget.size.width)
                    .clamp(0, double.infinity),
              ),
              child: Material(
                color: widget.row.selected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: TimedInkwell(
                  onTap: widget.row.onTap,
                  onDoubleTap: widget.row.onDoubleTap,
                  onLongPress: widget.row.onLongTap,
                  child: EntityContextMenu(
                    onOpen: () {
                      widget.row.onTap?.call();
                      widget.row.onDoubleTap?.call();
                    },
                    onCopy: () async {
                      /* final data = await ClipboardReader.readClipboard();
                      final pogData = await data.readValue(linuxFileUri);
                      print(pogData); */
                      await Pasteboard.writeFiles([widget.row.entity.path]);

                      /* final writer = ClipboardWriter.instance;
                      final item = DataWriterItem();

                      item.add(
                        linuxFileUri(Uri.file(widget.row.entity.path)),
                      );

                      await writer.write([item]);
                      print("Wrote"); */
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.horizontalPadding,
                      ),
                      child: Row(
                        children: widget.columns
                            .map((e) => _buildCell(widget.row.entity, e))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCell(EntityInfo entity, FilesColumn column) {
    late final Widget child;

    switch (column.type) {
      case FilesColumnType.name:
        child = Row(
          children: [
            Icon(
              entity.isDirectory
                  ? Utils.iconForFolder(entity.path)
                  : Utils.iconForPath(entity.path),
              color: entity.isDirectory
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                Utils.getEntityName(entity.path),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case FilesColumnType.date:
        child = Text(
          DateFormat("HH:mm - d MMM yyyy").format(entity.stat.modified),
          overflow: TextOverflow.ellipsis,
        );
      case FilesColumnType.type:
        final String fileExtension =
            p.extension(entity.path).replaceAll(".", "").toUpperCase();
        final String fileLabel =
            fileExtension.isNotEmpty ? "File ($fileExtension)" : "File";
        child = Text(
          entity.isDirectory ? "Directory" : fileLabel,
          overflow: TextOverflow.ellipsis,
        );
      case FilesColumnType.size:
        child = Text(
          entity.isDirectory ? "" : filesize(entity.stat.size),
          overflow: TextOverflow.ellipsis,
        );
    }

    return Container(
      width: column.normalizedWidth,
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}

final linuxFileUri = SimpleValueFormat(
  android: Formats.fileUri.android,
  ios: Formats.fileUri.ios,
  linux: const SimplePlatformCodec(
    formats: [
      'text/plain;charset=utf-8',
      'text/uri-list',
      'application/vnd.portal.files',
      'application/vnd.portal.filetransfer',
      'x-special/gnome-copied-files',
      'UTF8_STRING',
      'TARGETS',
      'TIMESTAMP',
      'text/plain',
      'application/octet-stream;extension=',
    ],
    decodingFormats: [
      'text/plain;charset=utf-8',
      'text/uri-list',
      'application/vnd.portal.files',
      'application/vnd.portal.filetransfer',
      'x-special/gnome-copied-files',
      'UTF8_STRING',
      'TARGETS',
      'TIMESTAMP',
      'text/plain',
      'application/octet-stream;extension=',
    ],
    encodingFormats: [
      'text/plain;charset=utf-8',
      'text/uri-list',
      'application/vnd.portal.files',
      'application/vnd.portal.filetransfer',
      'x-special/gnome-copied-files',
      'UTF8_STRING',
      'TARGETS',
      'TIMESTAMP',
      'text/plain',
      'application/octet-stream;extension=',
    ],
    onDecode: fileUriFromString,
    onEncode: fileUriToString,
  ),
  macos: Formats.fileUri.macos,
  windows: Formats.fileUri.windows,
  web: Formats.fileUri.web,
  fallback: Formats.fileUri.fallback,
);
