import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MarkdownWidget extends StatefulWidget {
  ///the markdown data
  final String data;

  ///if [tocController] is not null, you can use [tocListener] to get current TOC index
  final TocController? tocController;

  ///set the desired scroll physics for the markdown item list
  final ScrollPhysics? physics;

  ///set shrinkWrap to obtained [ListView] (only available when [tocController] is null)
  final bool shrinkWrap;

  /// [ListView] padding
  final EdgeInsetsGeometry? padding;

  ///make text selectable
  final bool selectable;

  ///the configs of markdown
  final MarkdownConfig? config;

  ///config for [MarkdownGenerator]
  final MarkdownGeneratorConfig? markdownGeneratorConfig;
  final MdConfig? mdConfig;

  const MarkdownWidget({
    Key? key,
    required this.data,
    this.tocController,
    this.physics,
    this.shrinkWrap = false,
    this.selectable = true,
    this.padding,
    this.config,
    this.markdownGeneratorConfig,
    this.mdConfig,
  }) : super(key: key);

  @override
  _MarkdownWidgetState createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget> {
  ///use [markdownGenerator] to transform markdown data to [Widget] list
  late MarkdownGenerator markdownGenerator;

  ///The markdown string converted by MarkdownGenerator will be retained in the [_widgets]
  final List<Widget> _widgets = [];

  ///[TocController] combines [TocWidget] and [MarkdownWidget]
  TocController? _tocController;

  ///[AutoScrollController] provides the scroll to index mechanism
  final AutoScrollController controller = AutoScrollController();

  ///every [VisibilityDetector]'s child which is visible will be kept with [indexTreeSet]
  final indexTreeSet = SplayTreeSet<int>((a, b) => a - b);

  ///if the [ScrollDirection] of [ListView] is [ScrollDirection.forward], [isForward] will be true
  bool isForward = true;
  List<Widget> alls = [];
  bool isFirstGetAll = true;

  @override
  void initState() {
    super.initState();
    _tocController = widget.tocController;
    _tocController?.jumpToIndexCallback = (index) {
      mdLog.i('进行跳转toc$index');
      controller.scrollToIndex(index,
          // duration: const Duration(milliseconds: 20),
          preferPosition: AutoScrollPosition.begin);
    };
    mdSignConfig = widget.mdConfig!;
    widget.mdConfig!.mdInitStateCall!(controller);
    mdObj.mdControl = controller;
    updateState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      int startTime = DateTime.now().millisecondsSinceEpoch;
      int endTime = DateTime.now().millisecondsSinceEpoch;
      mdLog.i('md本身-渲染完毕耗时：${(endTime - startTime) / 1000} s');
    });
  }

  ///when we've got the data, we need update data without setState() to avoid the flicker of the view
  void updateState() {
    indexTreeSet.clear();
    final generatorConfig =
        widget.markdownGeneratorConfig ?? MarkdownGeneratorConfig();
    markdownGenerator = MarkdownGenerator(
      config: widget.config,
      inlineSyntaxes: generatorConfig.inlineSyntaxList,
      blockSyntaxes: generatorConfig.blockSyntaxList,
      linesMargin: generatorConfig.linesMargin,
      generators: generatorConfig.generators,
      onNodeAccepted: generatorConfig.onNodeAccepted,
      textGenerator: generatorConfig.textGenerator,
    );
    final result =
        markdownGenerator.buildWidgets(widget.data, onTocList: (tocList) {
      _tocController?.setTocList(tocList);
    });
    // mdLog.i('md:$result');
    _widgets.addAll(result);
    mdObj.widgets = _widgets;
  }

  ///this method will be called when [updateState] or [dispose]
  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
  }

  @override
  void dispose() {
    clearState();
    controller.dispose();
    _tocController?.jumpToIndexCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildMarkdownWidget();

  ///
  Widget buildMarkdownWidget() {
    ListView mdListViewWidget = ListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      controller: controller,
      itemBuilder: (ctx, index) {
        Widget itemWidget = wrapByAutoScroll(index,
            wrapByVisibilityDetector(index, _widgets[index]), controller);

        Widget getHeight1 = LayoutBuilder(
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // 检查组件是否仍处于活动状态
              if (mounted) {
                RenderBox? itemBox = context.findRenderObject() as RenderBox?;
                double itemHeight = itemBox!.size.height;
                mdLog.i('height: $itemHeight, index: $index');
                mdObj.height[index] = itemHeight;
                if (index == _widgets.length - 1 &&
                    mdSignConfig.getMdObjCall != null) {
                  mdSignConfig.getMdObjCall!(mdObj);
                }
              }
            });
            return itemWidget;
          },
        );

        final itemKey = GlobalKey();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final RenderBox? itemBox =
              itemKey.currentContext?.findRenderObject() as RenderBox?;
        });
        /* return Container(
            key: itemKey,
            child: itemWidget,
          ); */
        // return getHeight1;
        return itemWidget;
      },
      itemCount: _widgets.length,
      padding: widget.padding,
    );
    final markdownWidget = NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        final ScrollDirection direction = notification.direction;
        isForward = direction == ScrollDirection.forward;
        return true;
      },
      child: mdListViewWidget,
    );
    Widget select = widget.selectable
        ? SelectionArea(
            onSelectionChanged: mdSignConfig.onSelectionChanged,
            child: markdownWidget)
        : markdownWidget;

    Widget all = ListView(
      children: List<Widget>.generate(_widgets.length, (index) {
        Widget itemWidget = wrapByAutoScroll(index,
            wrapByVisibilityDetector(index, _widgets[index]), controller);
        final itemKey = GlobalKey();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final RenderBox? itemBox =
              itemKey.currentContext?.findRenderObject() as RenderBox?;
          if (itemBox != null) {
            final double itemHeight = itemBox.size.height;
            mdObj.height[index] = itemHeight;
            mdLog.i('height: $itemHeight, index: $index');
          }
        });

        return Container(
          key: itemKey,
          child: itemWidget,
        );
      }),
    );
    /* return Container(
      child: Column(
        children: [
          // select,
          all,
        ],
      ),
    ); */
    return select;
  }

  ///wrap widget by [VisibilityDetector] that can know if [child] is visible
  Widget wrapByVisibilityDetector(int index, Widget child) {
    return VisibilityDetector(
      key: ValueKey(index.toString()),
      onVisibilityChanged: (VisibilityInfo info) {
        final visibleFraction = info.visibleFraction;
        if (isForward) {
          visibleFraction == 0
              ? indexTreeSet.remove(index)
              : indexTreeSet.add(index);
        } else {
          visibleFraction == 1.0
              ? indexTreeSet.add(index)
              : indexTreeSet.remove(index);
        }
        if (indexTreeSet.isNotEmpty) {
          _tocController?.onIndexChanged(indexTreeSet.first);
        }
      },
      child: child,
    );
  }

  @override
  void didUpdateWidget(MarkdownWidget oldWidget) {
    clearState();
    updateState();
    super.didUpdateWidget(widget);
  }
}

///wrap widget by [AutoScrollTag] that can use [AutoScrollController] to scrollToIndex
Widget wrapByAutoScroll(
    int index, Widget child, AutoScrollController controller) {
  return AutoScrollTag(
    key: Key(index.toString()),
    controller: controller,
    index: index,
    highlightColor: Colors.black.withOpacity(0.1),
    child: child,
  );
}
