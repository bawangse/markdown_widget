import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as m;

import '../widget/blocks/leaf/heading.dart';
import '../widget/widget_visitor.dart';
import 'configs.dart';
import 'toc.dart';

///use [MarkdownGenerator] to transform markdown data to [Widget] list, so you can render it by any type of [ListView]
class MarkdownGenerator {
  final MarkdownConfig config;
  final Iterable<m.InlineSyntax> inlineSyntaxes;
  final Iterable<m.BlockSyntax> blockSyntaxes;
  final EdgeInsets linesMargin;
  final List<SpanNodeGeneratorWithTag> generators;
  final SpanNodeAcceptCallback? onNodeAccepted;
  final TextNodeGenerator? textGenerator;

  MarkdownGenerator({
    MarkdownConfig? config,
    this.inlineSyntaxes = const [],
    this.blockSyntaxes = const [],
    this.linesMargin = const EdgeInsets.symmetric(vertical: 8),
    this.generators = const [],
    this.onNodeAccepted,
    this.textGenerator,
  }) : config = config ?? MarkdownConfig.defaultConfig;

  ///convert [data] to widgets
  ///[onTocList] can provider [Toc] list
  List<Widget> buildWidgets(String data,
      {ValueCallback<List<Toc>>? onTocList}) {
    final m.Document document = m.Document(
      extensionSet: m.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      inlineSyntaxes: inlineSyntaxes,
      blockSyntaxes: blockSyntaxes,
    );
    // lines是啥？每一行的字符串
    final List<String> lines = data.split(RegExp(r'(\r?\n)|(\r?\t)|(\r)'));
// 这里面返回的是node，对字符串进行了处理，所以100行字符串可能有20个node
    final List<m.Node> nodes = document.parseLines(lines);
    final List<Toc> tocList = [];
    final visitor = WidgetVisitor(
        config: config,
        generators: generators,
        textGenerator: textGenerator,
        onNodeAccepted: (node, index) {
          onNodeAccepted?.call(node, index);
          if (node is HeadingNode) {
            final listLength = tocList.length;
            tocList.add(
                Toc(node: node, widgetIndex: index, selfIndex: listLength));
          }
        });
    // nodes的数量就是spans的数量
    final spans = visitor.visit(nodes);
    // mdLog.i('对比：${spans.length}  ${nodes.length}');
    onTocList?.call(tocList);
    final List<Widget> widgets = [];
    for (var i = 0; i < spans.length; i++) {
      InlineSpan span = spans[i].build();
      if(span is TextSpan){
        ///fix: line breaks are not effective when copying.
        ///see [https://github.com/asjqkkkk/markdown_widget/issues/105]
        ///see [https://github.com/asjqkkkk/markdown_widget/issues/95]
        span.children?.add(TextSpan(text: '\r'));
      }
      // var node = nodes[i];
      // 如果要放到外面的话，下面的 widgets.add 要进行处理。
      Widget text = Text.rich(span);
      if (mdSignConfig.initMdNode != null) {
        text = mdSignConfig.initMdNode!(nodes, i, span);
      }
      mdObj.text[i] = nodes[i].textContent;
      widgets.add(Padding(
        padding: linesMargin,
        child: text,
      ));
    }
    return widgets;
  }
}

///use [MarkdownGeneratorConfig] for [MarkdownGenerator]
class MarkdownGeneratorConfig {
  final Iterable<m.InlineSyntax> inlineSyntaxList;
  final Iterable<m.BlockSyntax> blockSyntaxList;
  final EdgeInsets linesMargin;
  final List<SpanNodeGeneratorWithTag> generators;
  final SpanNodeAcceptCallback? onNodeAccepted;
  final TextNodeGenerator? textGenerator;

  MarkdownGeneratorConfig({
    this.inlineSyntaxList = const [],
    this.blockSyntaxList = const [],
    this.linesMargin = const EdgeInsets.all(4),
    this.generators = const [],
    this.onNodeAccepted,
    this.textGenerator,
  });
}
