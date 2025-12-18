import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class RubyGrammar extends MatcherGrammar {
  const RubyGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_regexps),
    Matcher.include(_symbols),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_variables),
    Matcher.include(_types),
    Matcher.include(_functions),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _comments() => Matcher.options([
    Matcher.regex(r'#.*$', tag: Tags.lineComment),
    Matcher.wrapped(
      begin: Matcher.regex(
        r'^=begin',
        tag: const Tag('begin', parent: Tags.blockComment),
      ),
      end: Matcher.regex(
        r'^=end',
        tag: const Tag('end', parent: Tags.blockComment),
      ),
      content: Matcher.regex(
        r'.+?(?=^=end|$)',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
      tag: Tags.blockComment,
    ),
  ]);

  Matcher _strings() => Matcher.options([
    Matcher.include(_heredocString),
    Matcher.include(_percentString),
    Matcher.include(_doubleQuotedString),
    Matcher.include(_singleQuotedString),
    Matcher.include(_backtickString),
  ]);

  /// Ruby heredocs can span multiple lines and are
  /// delimited by a dynamic identifier (such as `<<~EOF ... EOF`).
  /// Currently, we only highlight the heredoc opener.
  Matcher _heredocString() => Matcher.regex(
    "<<[-~]?(?:\\w+|\"\\w+\"|'\\w+')",
    tag: Tags.stringLiteral,
  );

  Matcher _percentString() => Matcher.options([
    // Interpolated forms: %Q{...}, %W{...}, or %{...}.
    Matcher.include(_percentBracesInterpolatedString),
    Matcher.include(_percentBracketsInterpolatedString),
    Matcher.include(_percentParensInterpolatedString),
    Matcher.include(_percentAnglesInterpolatedString),

    // Raw forms: %q{...}, %w{...}.
    Matcher.include(_percentBracesRawString),
    Matcher.include(_percentBracketsRawString),
    Matcher.include(_percentParensRawString),
    Matcher.include(_percentAnglesRawString),

    // Fallback single-line form with arbitrary delimiter: %Q|...|.
    Matcher.regex(r'%[qQwW]?([^\w\s]).*?\1', tag: Tags.stringLiteral),
  ]);

  Matcher _percentBracesInterpolatedString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[QW]?\{',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '}',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _interpolatedDelimitedStringContent('}'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentBracketsInterpolatedString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[QW]?\[',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      ']',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _interpolatedDelimitedStringContent(']'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentParensInterpolatedString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[QW]?\(',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      ')',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _interpolatedDelimitedStringContent(')'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentAnglesInterpolatedString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[QW]?<',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '>',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _interpolatedDelimitedStringContent('>'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentBracesRawString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[qw]\{',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '}',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _rawDelimitedStringContent('}'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentBracketsRawString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[qw]\[',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      ']',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _rawDelimitedStringContent(']'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentParensRawString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[qw]\(',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      ')',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _rawDelimitedStringContent(')'),
    tag: Tags.stringLiteral,
  );

  Matcher _percentAnglesRawString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'%[qw]<',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '>',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: _rawDelimitedStringContent('>'),
    tag: Tags.stringLiteral,
  );

  String _escapeForCharClass(String value) {
    return switch (value) {
      // These need escaping to be treated literally inside a character class.
      ']' => r'\]',
      '-' => r'\-',
      '^' => r'\^',
      r'\' => r'\\',
      // Most other punctuation does not need escaping in a character class.
      _ => value,
    };
  }

  Matcher _interpolatedDelimitedStringContent(String closingDelimiter) {
    final closing = _escapeForCharClass(closingDelimiter);
    return Matcher.options([
      Matcher.regex(r'#\{[^}]*\}', tag: Tags.stringInterpolation),
      Matcher.regex(r'#[@$]\w+', tag: Tags.stringInterpolation),
      Matcher.regex(r'\\.', tag: Tags.stringEscape),
      Matcher.regex('[^#$closing\\x5C]+', tag: Tags.stringContent),
      Matcher.regex(r'#(?!\{|[@$])', tag: Tags.stringContent),
    ], tag: Tags.stringContent);
  }

  Matcher _rawDelimitedStringContent(String closingDelimiter) {
    final closing = _escapeForCharClass(closingDelimiter);
    return Matcher.options([
      Matcher.regex(r'\\.', tag: Tags.stringEscape),
      Matcher.regex('[^$closing\\x5C]+', tag: Tags.stringContent),
    ], tag: Tags.stringContent);
  }

  Matcher _doubleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r'#\{[^}]*\}', tag: Tags.stringInterpolation),
      Matcher.regex(r'#[@$]\w+', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[nrtbfaesv"'\\0]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{1,2}', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\u\{[0-9a-fA-F]+\}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\c.', tag: Tags.stringEscape),
      Matcher.regex(r'\\M-\\C-.', tag: Tags.stringEscape),
      Matcher.regex(r'[^"\\#]+', tag: Tags.stringContent),
      Matcher.regex(r'#(?!\{|[@$])', tag: Tags.stringContent),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _singleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      "'",
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r"\\'", tag: Tags.stringEscape),
      Matcher.regex(r'\\\\', tag: Tags.stringEscape),
      Matcher.regex(r"[^'\\]+", tag: Tags.stringContent),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _backtickString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '`',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '`',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r'#\{[^}]*\}', tag: Tags.stringInterpolation),
      Matcher.regex(r'#[@$]\w+', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[nrtbfaesv`'\\0]""", tag: Tags.stringEscape),
      Matcher.regex(r'[^`\\#]+', tag: Tags.stringContent),
      Matcher.regex(r'#(?!\{|[@$])', tag: Tags.stringContent),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _regexps() => Matcher.options([
    Matcher.regex(r'%r\{[^}]*\}[imxousen]*', tag: Tags.regexpLiteral),
    Matcher.regex(r'%r\[[^\]]*\][imxousen]*', tag: Tags.regexpLiteral),
    Matcher.regex(r'%r\([^)]*\)[imxousen]*', tag: Tags.regexpLiteral),
    Matcher.regex(r'%r<[^>]*>[imxousen]*', tag: Tags.regexpLiteral),
    Matcher.regex(r'%r([^\w\s]).*?\1[imxousen]*', tag: Tags.regexpLiteral),
    Matcher.regex(
      r'(?<!\w)/(?!\s)(?:[^/\\]|\\.)*?/[imxousen]*',
      tag: Tags.regexpLiteral,
    ),
  ]);

  Matcher _symbols() => Matcher.options([
    Matcher.regex(
      r'%[si]\{[^}]*\}',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r'%[si]\[[^\]]*\]',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r'%[si]\([^)]*\)',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r'%[si]<[^>]*>',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r'%[si]([^\w\s]).*?\1',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r':[a-zA-Z_][a-zA-Z0-9_]*[?!=]?',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r':"(?:[^"\\]|\\.)*"',
      tag: const Tag('symbol', parent: Tags.literal),
    ),
    Matcher.regex(
      r":'"
      r"(?:[^'\\]|\\.)*"
      r"'",
      tag: const Tag('symbol', parent: Tags.literal),
    ),
  ]);

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords([
    'begin',
    'break',
    'case',
    'do',
    'else',
    'elsif',
    'end',
    'ensure',
    'for',
    'if',
    'in',
    'next',
    'redo',
    'retry',
    'return',
    'then',
    'unless',
    'until',
    'when',
    'while',
  ]);

  Matcher _declarationKeywords() => Matcher.keywords([
    'alias',
    'class',
    'def',
    'defined?',
    'module',
    'undef',
  ]);

  Matcher _modifierKeywords() => Matcher.keywords([
    'attr_accessor',
    'attr_reader',
    'attr_writer',
    'extend',
    'include',
    'prepend',
    'private',
    'protected',
    'public',
    'refine',
    'using',
  ]);

  Matcher _exceptionKeywords() => Matcher.keywords([
    'raise',
    'rescue',
    'throw',
    'catch',
    'fail',
  ]);

  Matcher _otherKeywords() => Matcher.keywords([
    'and',
    'not',
    'or',
    'super',
    'yield',
    'lambda',
    'proc',
    'loop',
    '__callee__',
    '__dir__',
    '__method__',
  ]);

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nilLiteral),
    Matcher.include(_specialVariables),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nilLiteral() => Matcher.regex(
    r'\bnil\b(?![?!=])',
    tag: Tags.nullLiteral,
  );

  Matcher _specialVariables() => Matcher.options([
    Matcher.regex(r'\bself\b', tag: Tags.specialIdentifier),
    Matcher.regex(r'\b__FILE__\b', tag: Tags.specialIdentifier),
    Matcher.regex(r'\b__LINE__\b', tag: Tags.specialIdentifier),
    Matcher.regex(r'\b__ENCODING__\b', tag: Tags.specialIdentifier),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(r'\b0x[0-9a-fA-F_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0o[0-7_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0b[01_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0d[0-9_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.[\d_]+([eE][+-]?[\d_]+)?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d[\d_]*[eE][+-]?[\d_]+\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r'\b\d[\d_]*r\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b\d[\d_]*i\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b\d[\d_]*\b', tag: Tags.integerLiteral),
  ]);

  Matcher _variables() => Matcher.options([
    Matcher.regex(
      r'@@[a-zA-Z_][a-zA-Z0-9_]*',
      tag: const Tag('class', parent: Tags.variable),
    ),
    Matcher.regex(
      r'@[a-zA-Z_][a-zA-Z0-9_]*',
      tag: const Tag('instance', parent: Tags.variable),
    ),
    Matcher.regex(
      r'\$[a-zA-Z_][a-zA-Z0-9_]*',
      tag: const Tag('global', parent: Tags.variable),
    ),
    Matcher.regex(
      r'\$[0-9]+',
      tag: const Tag('global', parent: Tags.variable),
    ),
    Matcher.regex(
      r'\$[~&`+?!@=/\\,;.<>*$:-]',
      tag: const Tag('global', parent: Tags.variable),
    ),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.include(_builtInTypes),
    Matcher.include(_constants),
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Array',
    'BasicObject',
    'Binding',
    'Class',
    'Complex',
    'Data',
    'Dir',
    'ENV',
    'Encoding',
    'Enumerator',
    'FalseClass',
    'Fiber',
    'File',
    'Float',
    'Hash',
    'IO',
    'Integer',
    'Kernel',
    'MatchData',
    'Method',
    'Module',
    'NilClass',
    'Numeric',
    'Object',
    'Proc',
    'Process',
    'Range',
    'Rational',
    'Regexp',
    'Set',
    'String',
    'Struct',
    'Symbol',
    'Thread',
    'Time',
    'TrueClass',
    'UnboundMethod',
  ]);

  Matcher _constants() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _functions() => Matcher.options([
    // Method definitions: `def name`, `def name(args)`, `def name?`, ...
    Matcher.regex(
      r'(?:(?<=\bdef )|(?<=\bdef\t))'
      r'[a-zA-Z_][a-zA-Z0-9_]*[?!=]?',
      tag: Tags.function,
    ),

    // Calls with parentheses or brace blocks.
    Matcher.regex(
      r'\b[a-zA-Z_][a-zA-Z0-9_]*[?!]?(?=\s*[\(\{])',
      tag: Tags.function,
    ),

    // Calls that use a `do ... end` block.
    Matcher.regex(
      r'\b[a-zA-Z_][a-zA-Z0-9_]*[?!]?(?=\s+do\b)',
      tag: Tags.function,
    ),

    // Predicate/bang methods used without arguments, often at the end of
    // an expression (`result.nil?`, `valid?`, `mutate!`).
    Matcher.regex(
      r'\b[a-zA-Z_][a-zA-Z0-9_]*[?!](?=\s|$|[\])}.,;])',
      tag: Tags.function,
    ),

    // Calls with "bare" arguments (`puts "hi"`, `puts __FILE__`, `puts 1`).
    Matcher.regex(
      '\\b[a-zA-Z_][a-zA-Z0-9_]*[?!]?(?=\\s+'
      '(?!(?:if|unless|while|until|and|or|do|end|then|else|elsif|when)\\b)'
      '[_a-zA-Z0-9"\'@\$\\[\\(\\{:%/])',
      tag: Tags.function,
    ),
  ]);

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'<=>|===|=>|->|::|'
      r'<<=|>>=|\*\*=|\*\*|&&=|\|\|=|'
      r'&&|\|\||<<|>>|<=|>=|==|!=|=~|!~|'
      r'\.\.\.|\.\.|\+@|-@',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~]=?|[<>]=?|\?|!|=', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.regex(
    r'\b[a-z_][a-zA-Z0-9_]*[?!=]?\b',
    tag: Tags.identifier,
  );
}
