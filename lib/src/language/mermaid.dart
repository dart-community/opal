import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Approximate highlighting for Mermaid's common diagram families.
@internal
final class MermaidGrammar extends MatcherGrammar {
  const MermaidGrammar();

  static const Tag _colorTag = Tag('color', parent: Tags.literal);

  // Keep hyphenated names together without consuming an adjacent arrow.
  // Sequence diagrams add `x` since `-x` is an arrow there.
  static String _name({String arrowStarts = r'.\->='}) =>
      '[\\p{L}\\p{N}_]+(?:[.-](?![$arrowStarts])[\\p{L}\\p{N}_]+)*';
  static final String _identifier = _name();
  static final String _sequenceIdentifier = _name(arrowStarts: r'.\->=x');
  static const String _nameBoundary = r'[\p{L}\p{N}_.-]';
  // Nested options can consume indentation through their
  // default whitespace rule before a line-specific matcher is reached.
  static const String _lineStart = r'(?<=^[ \t]*)';

  /// A run of prose that keeps interior spaces but
  /// never leading or trailing ones.
  /// The [excluded] characters delimit the run, and
  /// [interior] bars further characters from the middle only.
  static String _prose(String excluded, {String interior = ''}) =>
      '[^$excluded\\s](?:[^$excluded$interior]*[^$excluded\\s])?';

  // Task names run up to the colon that introduces their metadata.
  static final String _taskName = '${_prose(':')}(?=[ \\t]*:)';
  // Direction statements and their targets are shared by most diagrams.
  static const String _directions = 'direction|TB|TD|BT|RL|LR';
  // Block keywords common to the bare and text-carrying sequence forms.
  static const String _sequenceBlocks =
      'loop|alt|else|opt|par|and|critical|option|break';

  @override
  List<Matcher> get matchers => [
    // Frontmatter is recognized before a diagram has been selected.
    // Within a flowchart, a bare `---` must remain an edge operator.
    Matcher.wrapped(
      begin: Matcher.regex(r'^---[ \t]*$', tag: Tags.metadata),
      end: Matcher.regex(r'^---[ \t]*$', tag: Tags.metadata),
      content: Matcher.regex(r'.+', tag: Tags.metadata),
    ),
    _diagram('flowchart-elk|flowchart|graph', _flowchart),
    _diagram('sequenceDiagram', _sequence),
    _diagram('classDiagram', _classDiagram),
    _diagram('stateDiagram-v2|stateDiagram', _stateDiagram),
    _diagram('erDiagram', _entityRelationship),
    _diagram('gantt', _gantt),
    _diagram('pie', _pie),
    _diagram('journey', _journey),
    _diagram('mindmap', _mindmap),
    _diagram('timeline', _timeline),
    _diagram('gitGraph', _gitGraph, allowColon: true),
    Matcher.include(_common),
  ];

  Matcher _diagram(
    String names,
    Matcher Function() body, {
    bool allowColon = false,
  }) => Matcher.wrapped(
    begin: Matcher.regex(
      '$_lineStart(?:$names)(?=[ \\t;${allowColon ? ':' : ''}]|\$)',
      tag: Tags.declarationKeyword,
    ),
    // The family remains selected to EOF.
    // All state belongs to this call to tokenize.
    end: null,
    content: Matcher.options([
      Matcher.include(_comments),
      Matcher.include(_accessibility),
      Matcher.include(_string),
      Matcher.include(body),
      Matcher.include(_common),
    ]),
  );

  Matcher _comments() => Matcher.options([
    Matcher.wrapped(
      begin: Matcher.verbatim('%%{', tag: Tags.metadata),
      end: Matcher.verbatim('}%%', tag: Tags.metadata),
      content: Matcher.regex(r'.+?(?=\}%%|$)', tag: Tags.metadata),
    ),
    Matcher.regex(r'%%.*$', tag: Tags.lineComment),
  ]);

  Matcher _accessibility() => Matcher.options([
    Matcher.wrapped(
      begin: Matcher.regex(r'\baccDescr[ \t]*\{', tag: Tags.metadata),
      end: Matcher.verbatim('}', tag: Tags.metadata),
      content: Matcher.regex(r'[^}]+', tag: Tags.unquotedString),
    ),
    _textLine(
      'accTitle|accDescr',
      separator: r'[ \t]*:[ \t]*',
      separatorTag: Tags.punctuation,
    ),
  ]);

  /// Quoted labels use `"`.
  /// Apostrophes and backticks in prose are ordinary text.
  /// Quotes within labels are written as entity codes.
  Matcher _string() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r'#\w+;', tag: Tags.stringEscape),
      Matcher.regex(r'[^"#]+', tag: Tags.stringContent),
      Matcher.verbatim('#', tag: Tags.stringContent),
    ]),
    tag: Tags.doubleQuoteString,
  );

  Matcher _words(String words, {Tag tag = Tags.keyword}) => Matcher.regex(
    '(?<!$_nameBoundary)(?:$words)(?!$_nameBoundary)',
    tag: tag,
  );

  Matcher _common() => Matcher.options([
    Matcher.include(_comments),
    Matcher.include(_string),
    Matcher.include(_numbers),
    Matcher.regex(_identifier, tag: Tags.identifier),
    // Entity codes stand in for characters that would otherwise
    // end a label or statement, such as `#35;` for `#`.
    Matcher.regex(r'#\w+;', tag: Tags.stringEscape),
    Matcher.regex(r'[{}()\[\],;:.@#]', tag: Tags.punctuation),
    Matcher.regex(r'[+*/=<>&|!~\-]', tag: Tags.operator),
  ]);

  Matcher _numbers() => Matcher.regex(
    r'(?<![\p{L}\p{N}_.])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'
    r'(?![\p{L}\p{N}_.])',
    tag: Tags.numberLiteral,
  );

  /// Line-based prose treats quotes, keywords, and comment markers as text.
  /// Surrounding whitespace is left to the default whitespace rule.
  Matcher _lineProse() => Matcher.options([
    Matcher.regex(_prose(r'\r\n'), tag: Tags.unquotedString),
  ]);

  /// Labels with quotation syntax can span lines inside quotes.
  /// Unquoted content stops at the end of the line.
  Matcher _quotedText() => Matcher.options([
    Matcher.include(_string),
    Matcher.regex(_prose('"', interior: r'\r\n'), tag: Tags.unquotedString),
  ]);

  Matcher _textLine(
    String words, {
    String separator = r'[ \t]+',
    Tag separatorTag = Tags.whitespace,
    bool atLineStart = true,
  }) => Matcher.wrapped(
    begin: Matcher.capture(
      '${atLineStart ? _lineStart : ''}($words)($separator)',
      captures: [Tags.keyword, separatorTag],
    ),
    end: Matcher.regex(r'$'),
    content: Matcher.include(_lineProse),
  );

  Matcher _colonText({bool allowQuoted = false}) => Matcher.wrapped(
    begin: Matcher.verbatim(':', tag: Tags.punctuation),
    end: Matcher.regex(r'$'),
    content: Matcher.include(allowQuoted ? _quotedText : _lineProse),
  );

  /// Gantt and journey rows both name a task first.
  /// Only the part following the `:` is metadata,
  /// so the description itself stays text.
  Matcher _taskLine() =>
      Matcher.regex('$_lineStart$_taskName', tag: Tags.unquotedString);

  Matcher _flowchart() => Matcher.options([
    Matcher.include(_properties),
    Matcher.include(_style),
    Matcher.include(_flowEdges),
    Matcher.include(_shapes),
    _label('|', '|'),
    _words('flowchart|graph|subgraph', tag: Tags.declarationKeyword),
    _words('end', tag: Tags.controlKeyword),
    _words('$_directions|click|call|href|callback'),
    Matcher.verbatim(':::', tag: Tags.punctuation),
  ]);

  // Check arrowheaded endings before their undirected prefixes.
  // Share this pattern so label content
  // stops exactly where the closing edge begins.
  // Dotted links grow with extra dots and require a hyphen before any head.
  static const String _flowLabelEnd =
      r'-{2,}[>ox]|={2,}[>ox]|\.+-[>ox]|-{3,}|={3,}|\.+-';

  // A link without either of its ends, shared by the labeled and bare forms.
  static const String _flowLinkBody = r'-{2,}|={2,}|-\.+-*';

  Matcher _flowEdges() => Matcher.options([
    // Inline labels can end with directed or undirected links,
    // such as `-- label -->` and `-- label ---`.
    // The surrounding whitespace is required,
    // so that an arrow like `-->` never begins a label.
    Matcher.wrapped(
      begin: Matcher.capture(
        r'([<ox]?(?:--|==|-\.))([ \t]+)(?=\S)',
        captures: [Tags.operator, Tags.whitespace],
      ),
      end: Matcher.regex('$_flowLabelEnd|\$', tag: Tags.operator),
      content: Matcher.options([
        Matcher.include(_string),
        // Check for the closing edge after even a single label character.
        Matcher.regex(
          '\\S(?:.*?\\S)??(?=[ \\t]*(?:$_flowLabelEnd|\$))',
          tag: Tags.unquotedString,
        ),
      ]),
    ),
    // A leading `<`, `o`, or `x` only starts a link when
    // the link closes with its counterpart.
    // Otherwise it names the node before the link, as in `x-->y`.
    Matcher.regex(
      '<(?:$_flowLinkBody)>|o(?:$_flowLinkBody)o|x(?:$_flowLinkBody)x'
      '|(?:$_flowLinkBody)[>ox]?|~{3,}',
      tag: Tags.operator,
    ),
  ]);

  Matcher _shapes() => Matcher.options([
    // Longest openings first. Bracket pairs can also mix slash directions.
    for (final (begin, end) in const [
      ('(((', ')))'),
      ('((', '))'),
      ('([', '])'),
      ('[[', ']]'),
      ('[(', ')]'),
      ('{{', '}}'),
    ])
      _label(begin, end),
    _label('[/', r'[/\\]\]', endIsPattern: true),
    _label('[\\', r'[/\\]\]', endIsPattern: true),
    _label('[', ']'),
    _label('(', ')'),
    _label('{', '}'),
    // Only an asymmetric node opens with `>`.
    // Ignore the one left behind by a malformed arrow so
    // it doesn't swallow the rest of the line.
    _label(r'(?<![-=.])>', ']', beginIsPattern: true),
  ]);

  Matcher _label(
    String begin,
    String end, {
    bool beginIsPattern = false,
    bool endIsPattern = false,
  }) {
    final endPattern = endIsPattern ? end : RegExp.escape(end);
    return Matcher.wrapped(
      begin: beginIsPattern
          ? Matcher.regex(begin, tag: Tags.punctuation)
          : Matcher.verbatim(begin, tag: Tags.punctuation),
      end: Matcher.regex('$endPattern|\$', tag: Tags.punctuation),
      content: Matcher.options([
        Matcher.include(_string),
        Matcher.regex(
          '(?:(?!$endPattern)[^"\\r\\n])+',
          tag: Tags.unquotedString,
        ),
      ]),
    );
  }

  Matcher _properties() => Matcher.wrapped(
    begin: Matcher.verbatim('@{', tag: Tags.punctuation),
    end: Matcher.regex(r'\}|$', tag: Tags.punctuation),
    content: Matcher.include(_propertyContent),
  );

  Matcher _propertyContent() => Matcher.options([
    Matcher.regex('$_identifier(?=[ \\t]*:)', tag: Tags.property),
    Matcher.include(_string),
    Matcher.regex(r'#[\da-fA-F]{3,8}\b', tag: _colorTag),
    _words('true', tag: Tags.trueLiteral),
    _words('false', tag: Tags.falseLiteral),
    Matcher.regex(r'\d+(?:\.\d+)?(?:px|em|%)', tag: Tags.numberLiteral),
    Matcher.include(_common),
  ]);

  // Style statements start a line or follow a semicolon,
  // with optional indentation.
  // The same words elsewhere can be node names.
  Matcher _style() => Matcher.wrapped(
    begin: Matcher.regex(
      r'(?<=(?:^|;)[ \t]*)(?:classDef|class|cssClass|style|linkStyle)'
      '(?!$_nameBoundary)',
      tag: Tags.keyword,
    ),
    end: Matcher.regex(r';|$', tag: Tags.punctuation),
    content: Matcher.include(_propertyContent),
  );

  Matcher _sequence() => Matcher.options([
    Matcher.include(_properties),
    Matcher.regex(r'(?:<<)?--?(?:>>|>|x|\))[-+]?', tag: Tags.operator),
    _sequenceText(Matcher.verbatim(':', tag: Tags.punctuation)),
    _sequenceTextLine('$_sequenceBlocks|rect|box', tag: Tags.controlKeyword),
    _sequenceTextLine('title'),
    _words('participant|actor|create|destroy', tag: Tags.declarationKeyword),
    _words('$_sequenceBlocks|end', tag: Tags.controlKeyword),
    _words(
      'activate|deactivate|autonumber|Note|note|over|right|left|of|'
      'links|link|properties',
    ),
    _sequenceText(_words('as')),
    Matcher.include(_numbers),
    Matcher.regex(_sequenceIdentifier, tag: Tags.identifier),
  ]);

  Matcher _sequenceTextLine(String words, {Tag tag = Tags.keyword}) =>
      _sequenceText(
        Matcher.capture(
          r'(?<=(?:^|;)[ \t]*)'
          '($words)([ \\t]+)',
          captures: [tag, Tags.whitespace],
        ),
      );

  // Sequence prose treats quotes as ordinary text.
  // A newline or literal semicolon ends a statement,
  // but entity codes keep their semicolons.
  Matcher _sequenceText(Matcher begin) => Matcher.wrapped(
    begin: begin,
    end: Matcher.regex(r';|$', tag: Tags.punctuation),
    content: Matcher.options([
      Matcher.regex(r'#\w+;', tag: Tags.stringEscape),
      Matcher.regex(_prose(r';#', interior: r'\r\n'), tag: Tags.unquotedString),
      Matcher.verbatim('#', tag: Tags.unquotedString),
    ]),
  );

  Matcher _classDiagram() => Matcher.options([
    _words('class|namespace', tag: Tags.declarationKeyword),
    Matcher.include(_style),
    Matcher.regex(r'<<[^>]+>>', tag: Tags.annotation),
    Matcher.include(_classRelationship),
    _words('$_directions|click|callback|link|note'),
    Matcher.regex(
      '(?<=^[ \\t]*note[ \\t]+)for(?!$_nameBoundary)',
      tag: Tags.keyword,
    ),
    Matcher.regex('$_identifier(?=[ \\t]*\\()', tag: Tags.function),
    Matcher.regex(
      r'(?<![\p{L}\p{N}_.])(?:int|bool|float|double|string|String|void)'
      '(?!$_nameBoundary)',
      tag: Tags.builtInType,
    ),
    Matcher.regex(r'[+#~*$-]', tag: Tags.modifierKeyword),
    Matcher.verbatim(':::', tag: Tags.punctuation),
  ]);

  // Unlike the `:` that introduces a member's type,
  // the one that follows a relationship introduces a label,
  // so the rest of the line is prose.
  Matcher _classRelationship() => Matcher.wrapped(
    begin: Matcher.regex(
      r'(?:<\|?|[o*])?(?:--|\.\.)(?:\|?>|[o*])?',
      tag: Tags.operator,
    ),
    end: Matcher.regex(r'$'),
    content: Matcher.options([
      Matcher.verbatim(':::', tag: Tags.punctuation),
      Matcher.include(_colonText),
      Matcher.include(_common),
    ]),
  );

  Matcher _stateDiagram() => Matcher.options([
    Matcher.include(_style),
    Matcher.regex(r'\[\*\]', tag: Tags.specialIdentifier),
    Matcher.regex(r'<<[^>]+>>', tag: Tags.annotation),
    Matcher.verbatim('-->', tag: Tags.operator),
    Matcher.verbatim('--', tag: Tags.punctuation),
    Matcher.verbatim(':::', tag: Tags.punctuation),
    Matcher.include(_colonText),
    _words('state', tag: Tags.declarationKeyword),
    _words('note|end', tag: Tags.controlKeyword),
    _words('as|$_directions|right|left|of'),
  ]);

  Matcher _entityRelationship() => Matcher.options([
    // Match cardinalities as part of the relationship, before punctuation.
    Matcher.regex(
      r'(?:\|[|o]|[o|]\{|\}[o|])(?:--|\.\.)(?:[|o]\||[o|]\{|\}[o|])',
      tag: Tags.operator,
    ),
    // ER relationship labels support quotes, unlike state/class prose.
    Matcher.include(() => _colonText(allowQuoted: true)),
    _words('PK|FK|UK', tag: Tags.modifierKeyword),
    _words(_directions),
    _words(
      'int|string|boolean|float|double|date|datetime',
      tag: Tags.builtInType,
    ),
  ]);

  Matcher _gantt() => Matcher.options([
    _textLine(
      'title|section|dateFormat|axisFormat|tickInterval|excludes|includes|'
      'todayMarker|weekday|weekend',
    ),
    _words('inclusiveEndDates|topAxis'),
    Matcher.include(_taskLine),
    _words('active|done|crit|milestone|after|until|vert'),
    Matcher.regex(r'\b\d{4}-\d{2}-\d{2}\b', tag: Tags.literal),
    Matcher.regex(
      r'\b\d+(?:\.\d+)?(?:ms|[smhdwMy])\b',
      tag: Tags.numberLiteral,
    ),
  ]);

  Matcher _pie() => Matcher.options([
    _words('showData'),
    // The title may share the header line: `pie showData title Pets`.
    _textLine('title', atLineStart: false),
  ]);

  Matcher _journey() => Matcher.options([
    _textLine('title|section'),
    Matcher.include(_taskLine),
  ]);

  Matcher _mindmap() => Matcher.options([
    Matcher.regex(r'::icon\([^)]*\)', tag: Tags.annotation),
    Matcher.regex(r':::[\w-]+', tag: Tags.annotation),
    // Bang and cloud shapes invert the usual bracket direction.
    _label('))', '(('),
    _label(')', '('),
    Matcher.include(_shapes),
    Matcher.regex(_prose(r'()[\]{}:'), tag: Tags.unquotedString),
  ]);

  Matcher _timeline() => Matcher.options([
    _textLine('title|section'),
    // A period can list several events, each introduced by its own colon.
    Matcher.wrapped(
      begin: Matcher.verbatim(':', tag: Tags.punctuation),
      end: Matcher.regex(r':|$', tag: Tags.punctuation),
      content: Matcher.options([
        Matcher.include(_string),
        Matcher.regex(_prose('":'), tag: Tags.unquotedString),
      ]),
    ),
    Matcher.regex(_prose(':'), tag: Tags.unquotedString),
  ]);

  Matcher _gitGraph() => Matcher.options([
    _words(
      'commit|branch|checkout|switch|merge|cherry-pick',
      tag: Tags.keyword,
    ),
    _words('LR|TB|BT'),
    _words('NORMAL|REVERSE|HIGHLIGHT', tag: Tags.modifierKeyword),
    Matcher.regex('$_identifier(?=[ \\t]*:)', tag: Tags.property),
  ]);
}
