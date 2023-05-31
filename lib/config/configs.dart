import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:markdown/markdown.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../widget/all.dart';

Logger mdLog = Logger(
  printer: PrettyPrinter(
      methodCount: 1, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      printTime: true // Should each log print contain a timestamp
      ),
);

// 用来保存md的数据，用来传递给外部
class MdData {
  /// 记录item的高度，key是 index ，值是高度
  Map height = {};

  /// 记录item的值，key是 index ，值是text-而不是node
  Map text = {};

  /// 记录item的值，key是 index ，值是text-而不是node
  List<Widget> widgets = [];

  /// md本身的control
  AutoScrollController? mdControl;

  /// toc本身的control
  AutoScrollController? tocControl;
}

MdData mdObj = MdData();

class MdConfig {
  // int tocIndex; // toc里面是第几个listItem
  // int tocoffset; // toc当前距离当前的高度
  // md的initState调用
  /// md初始化时要做的事情
  void Function(AutoScrollController)? mdInitStateCall;

  /// toc初始化时要做的事情
  void Function(AutoScrollController)? tocInitStateCall;

  /// toc里面点击目录时要做的事情
  void Function(int)? clickTocCall;

  /// md的height参数计算完毕啦
  void Function(MdData mdObj)? getMdObjCall;

  /// 选中文本时要做的事情
  void Function(SelectedContent?)? onSelectionChanged;

  /// 初始化md时，对md的组件进行改造，主要用于给md组件加些额外的操作，比如行双击
  Widget Function(List<Node> nodes, int index, InlineSpan span)? initMdNode;

  /// 阅读md的index，使用对象传递，['index']
  Map? mdReadObj;

  /// md的style，普通行、间隔行设置的背景色是不同的
  TextStyle? commonStyle;
  TextStyle? highLightStyle;

  MdConfig({
    this.mdInitStateCall,
    this.tocInitStateCall,
    this.clickTocCall,
    this.getMdObjCall,
    this.onSelectionChanged,
    this.initMdNode,
    this.mdReadObj,
    this.commonStyle,
    this.highLightStyle,
  });
}

/// 真正初始化在 lib/source/markdown_widget/lib/widget/markdown.dart 的initState里面
var mdSignConfig = MdConfig();

abstract class WidgetConfig {
  ///every config has a tag
  String get tag;
}

//the basic block config interface
abstract class BlockConfig implements WidgetConfig {}

//the inline widget config interface
abstract class InlineConfig implements WidgetConfig {}

//the container block config interface
abstract class ContainerConfig implements BlockConfig {}

//the leaf block config interface
abstract class LeafConfig implements BlockConfig {}

typedef ValueCallback<T> = void Function(T value);

///the tags of markdown, see [https://spec.commonmark.org/0.30/]
enum MarkdownTag {
  ///------------------------------------------------------///
  ///container block: which can contain other blocks///

  /// [blockquote] A block quote marker, optionally preceded by up to three spaces of indentation,
  ///consists of (a) the character > together with a following space of indentation,
  ///or (b) a single character > not followed by a space of indentation.
  blockquote,

  /// [ul] unordered list
  /// [ol] ordered list
  /// [li] A list is a sequence of one or more list items of the same type.
  /// The list items may be separated by any number of blank lines.
  ul,
  ol,
  li,

  /// [table]
  ///
  /// It consists of rows and columns,
  /// with each row separated by a new line and each cell within a row separated by a pipe symbol (|)
  table,
  thead,
  tbody,
  tr,
  th,
  td,

  ///----------------------------------------------------///
  ///leaf block: which can not contain other blocks///

  /// [hr] Thematic breaks, also known as horizontal rules
  hr,

  /// [pre] An indented code block is composed of one or more indented chunks separated by blank lines
  /// A code fence is a sequence of at least three consecutive backtick characters (`) or tildes (~)
  pre,

  ///[h1]、[h2]、[h3]、[h4]、[h5]、[h6]
  ///An ATX heading consists of a string of characters
  ///A setext heading consists of one or more lines of text
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,

  /// [a] Link reference definitions,A link reference definition consists of a link label
  a,

  /// [p] A sequence of non-blank lines that cannot be interpreted as other kinds of blocks forms a paragraph
  p,

  ///----------------------------------------------------///
  ///inlines: which is contained by blocks

  ///[code] A code fence is a sequence of at least three consecutive backtick characters (`) or tildes (~)
  code,

  ///[em] emphasis, Markdown treats asterisks (*) and underscores (_) as indicators of emphasis
  em,

  ///[del] double '~'swill be wrapped with an HTML <del> tag.
  del,

  ///[br] a hard line break
  br,

  ///[strong] double '*'s or '_'s will be wrapped with an HTML <strong> tag.
  strong,

  ///[img] a image tag
  img,

  ///[input] a checkbox, use '- [ ] ' or '- [x] '
  input,
  other
}

///use [MarkdownConfig] to set various configurations for [MarkdownWidget]
class MarkdownConfig {
  HrConfig get hr => _getConfig<HrConfig>(MarkdownTag.hr, const HrConfig());

  H1Config get h1 => _getConfig<H1Config>(MarkdownTag.h1, const H1Config());

  H2Config get h2 => _getConfig<H2Config>(MarkdownTag.h2, const H2Config());

  H3Config get h3 => _getConfig<H3Config>(MarkdownTag.h3, const H3Config());

  H4Config get h4 => _getConfig<H4Config>(MarkdownTag.h4, const H4Config());

  H5Config get h5 => _getConfig<H5Config>(MarkdownTag.h5, const H5Config());

  H6Config get h6 => _getConfig<H6Config>(MarkdownTag.h6, const H6Config());

  PreConfig get pre =>
      _getConfig<PreConfig>(MarkdownTag.pre, const PreConfig());

  LinkConfig get a => _getConfig<LinkConfig>(MarkdownTag.a, const LinkConfig());

  PConfig get p => _getConfig<PConfig>(MarkdownTag.p, const PConfig());

  BlockquoteConfig get blockquote => _getConfig<BlockquoteConfig>(
      MarkdownTag.blockquote, const BlockquoteConfig());

  ListConfig get li =>
      _getConfig<ListConfig>(MarkdownTag.li, const ListConfig());

  TableConfig get table =>
      _getConfig<TableConfig>(MarkdownTag.table, const TableConfig());

  CodeConfig get code =>
      _getConfig<CodeConfig>(MarkdownTag.code, const CodeConfig());

  ImgConfig get img =>
      _getConfig<ImgConfig>(MarkdownTag.img, const ImgConfig());

  CheckBoxConfig get input =>
      _getConfig<CheckBoxConfig>(MarkdownTag.input, const CheckBoxConfig());

  T _getConfig<T>(MarkdownTag tag, T defaultValue) {
    final config = _tag2Config[tag.name];
    if (config == null || config is! T) {
      return defaultValue;
    }
    return config as T;
  }

  ///default [MarkdownConfig] for [MarkdownWidget]
  static MarkdownConfig get defaultConfig => MarkdownConfig();

  ///[darkConfig] is used for dark mode
  static MarkdownConfig get darkConfig => MarkdownConfig(configs: [
        HrConfig.darkConfig,
        H1Config.darkConfig,
        H2Config.darkConfig,
        H3Config.darkConfig,
        H4Config.darkConfig,
        H5Config.darkConfig,
        H6Config.darkConfig,
        PreConfig.darkConfig,
        PConfig.darkConfig,
        CodeConfig.darkConfig,
      ]);

  ///the key of [_tag2Config] is tag, the value is [WidgetConfig]
  final Map<String, WidgetConfig> _tag2Config = {};

  MarkdownConfig({List<WidgetConfig> configs = const []}) {
    for (final config in configs) {
      _tag2Config[config.tag] = config;
    }
  }

  MarkdownConfig copy({List<WidgetConfig> configs = const []}) {
    for (final config in configs) {
      _tag2Config[config.tag] = config;
    }
    return MarkdownConfig(configs: _tag2Config.values.toList());
  }
}
