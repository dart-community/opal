import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical LLVM IR highlighting with a small amount of local context.
@internal
final class LlvmGrammar extends MatcherGrammar {
  const LlvmGrammar();

  static const String _namePart = r'[-a-zA-Z$._0-9]';
  static const String _name = '[-a-zA-Z\$._]$_namePart*';
  // A word boundary is insufficient:
  // dots, hyphens, and sigils are part of LLVM names.
  // Also keep malformed numeric/name fragments together.
  static const String _left = r'(?<![-a-zA-Z$._0-9%@!#^\\])';
  static const String _right = r'(?![-a-zA-Z$._0-9\\])';

  @override
  List<Matcher> get matchers => [
    Matcher.regex(r'\s+', tag: Tags.whitespace),
    // LLVM prints a basic-block label alone on its line
    // apart from a trailing comment,
    // while a metadata, summary, or attribute field's value
    // follows on the same line.
    _quoted(begin: r'"(?=[^"]*":[ \t]*(?:;|$))', tag: Tags.label),
    Matcher.regex('$_namePart+(?=:[ \\t]*(?:;|\$))', tag: Tags.label),
    Matcher.regex('$_name(?=[ \\t]*:)', tag: Tags.property),
    // Common punctuation and operators that no other token can start with.
    // Checking them first avoids trying every other matcher on them.
    Matcher.regex(r'[,:()\[\]{}<>]|\.\.\.', tag: Tags.punctuation),
    Matcher.regex(r'[=*|]', tag: Tags.operator),
    Matcher.regex(r';.*$', tag: Tags.lineComment),
    _blockComment,
    // These refinements deliberately only inspect the current line.
    _symbol('@', tag: Tags.function, following: r'[ \t]*\('),
    _symbol('%', tag: Tags.type, following: '[ \\t]*=[ \\t]*type$_right'),
    _symbol(
      '%',
      tag: Tags.label,
      preceding: '(?<=${_left}label[ \\t]+)',
    ),
    _symbol('%'),
    _symbol('@'),
    // Unquoted comdat names are left to the identifier fallback.
    _quoted(begin: r'\$"', tag: Tags.identifier),
    Matcher.options([
      _quoted(begin: '!"', tag: Tags.doubleQuoteString),
    ], tag: Tags.metadata),
    Matcher.regex(
      r'(?:!(?:[-a-zA-Z$._\\][-a-zA-Z$._0-9\\]*|[0-9]+)|[#^][0-9]+|'
      r'#dbg_[a-zA-Z_][a-zA-Z_0-9]*)'
      '$_right',
      tag: Tags.metadata,
    ),
    _quoted(begin: '${_left}c"', tag: Tags.doubleQuoteString),
    _quoted(begin: '"', tag: Tags.doubleQuoteString),
    _numbers,
    _words(const {'true'}, Tags.trueLiteral),
    _words(const {'false'}, Tags.falseLiteral),
    _words(const {'null'}, Tags.nullLiteral),
    _words(const {
      'none',
      'poison',
      'undef',
      'zeroinitializer',
    }, Tags.literal),
    // Debug-info enumerators, such as DW_LANG_C,
    // DIFlagPrototyped, and FullDebug, are the only capitalized keywords.
    _bounded(r'[A-Z][a-zA-Z_0-9]*', Tags.literal),
    _words(const {
      'bfloat',
      'double',
      'float',
      'fp128',
      'half',
      'label',
      'metadata',
      'opaque',
      'ppc_fp128',
      'ptr',
      'token',
      'void',
      'x86_amx',
      'x86_fp80',
      'x86_mmx',
    }, Tags.builtInType),
    _bounded(r'[ib][0-9]+', Tags.builtInType),
    _words(const {
      'br',
      'call',
      'callbr',
      'catchret',
      'catchswitch',
      'cleanupret',
      'indirectbr',
      'invoke',
      'resume',
      'ret',
      'switch',
      'unreachable',
      'unwind',
    }, Tags.controlKeyword),
    _words(const {
      'alias',
      'attributes',
      'comdat',
      'constant',
      'datalayout',
      'declare',
      'define',
      'global',
      'ifunc',
      'module',
      'source_filename',
      'target',
      'triple',
      'type',
      'uselistorder',
      'uselistorder_bb',
    }, Tags.declarationKeyword),
    _words(const {
      // Instructions.
      'add',
      'addrspacecast',
      'alloca',
      'and',
      'ashr',
      'atomicrmw',
      'bitcast',
      'catchpad',
      'cleanuppad',
      'cmpxchg',
      'extractelement',
      'extractvalue',
      'fadd',
      'fcmp',
      'fdiv',
      'fence',
      'fmul',
      'fneg',
      'fpext',
      'fptosi',
      'fptoui',
      'fptrunc',
      'freeze',
      'frem',
      'fsub',
      'getelementptr',
      'icmp',
      'insertelement',
      'insertvalue',
      'inttoptr',
      'landingpad',
      'load',
      'lshr',
      'mul',
      'or',
      'phi',
      'ptrtoaddr',
      'ptrtoint',
      'sdiv',
      'select',
      'sext',
      'shl',
      'shufflevector',
      'sitofp',
      'srem',
      'store',
      'sub',
      'trunc',
      'udiv',
      'uitofp',
      'urem',
      'va_arg',
      'xor',
      'zext',
      // Constant expressions, instruction clauses, and type syntax.
      'asm',
      'blockaddress',
      'caller',
      'catch',
      'cleanup',
      'distinct',
      'dso_local_equivalent',
      'filter',
      'no_cfi',
      'personality',
      'ptrauth',
      'splat',
      'to',
      'vscale',
      'within',
      'x',
    }, Tags.keyword),
    // Comparison predicates.
    _words(const {
      'eq',
      'ne',
      'oeq',
      'oge',
      'ogt',
      'ole',
      'olt',
      'one',
      'ord',
      'sge',
      'sgt',
      'sle',
      'slt',
      'ueq',
      'uge',
      'ugt',
      'ule',
      'ult',
      'une',
      'uno',
    }, Tags.operator),
    // LLVM IR has no bare identifiers, so any other bare word is
    // an attribute, linkage, calling convention, flag, or similar.
    _bounded(r'[a-zA-Z_][a-zA-Z_0-9]*', Tags.modifierKeyword),
    Matcher.verbatim('!', tag: Tags.metadata),
    // Include numeric-looking words here so an unfamiliar/malformed spelling
    // is consumed once, rather than repeatedly scanning its suffix.
    Matcher.regex('$_namePart+', tag: Tags.identifier),
  ];

  // Whitespace is matched first, so skip retrying
  // the default whitespace rule at the end of every options matcher.
  @override
  List<Matcher> get postAppliedMatchers => const [];

  static final Matcher _blockComment = Matcher.wrapped(
    begin: Matcher.verbatim(
      '/*',
      tag: const Tag('begin', parent: Tags.blockComment),
    ),
    end: Matcher.verbatim(
      '*/',
      tag: const Tag('end', parent: Tags.blockComment),
    ),
    // LLVM block comments do not nest.
    content: Matcher.regex(
      r'[^*]+|\*+(?!/)',
      tag: const Tag('content', parent: Tags.blockComment),
    ),
    tag: Tags.blockComment,
  );

  static Matcher _symbol(
    String sigil, {
    Tag tag = Tags.variable,
    String preceding = '',
    String following = '',
  }) {
    final escapedSigil = RegExp.escape(sigil);
    final prefix = '$preceding$escapedSigil';
    final tail = following.isEmpty ? '' : '(?=$following)';
    final quotedTail = following.isEmpty ? '' : '(?=[^"]*"$following)';
    return Matcher.options([
      _quoted(begin: '$prefix"$quotedTail', tag: tag),
      Matcher.regex('$prefix(?:$_name|[0-9]+)$_right$tail', tag: tag),
    ]);
  }

  static Matcher _quoted({required String begin, required Tag tag}) =>
      Matcher.wrapped(
        begin: Matcher.regex(begin, tag: Tag('begin', parent: tag)),
        end: Matcher.verbatim('"', tag: Tag('end', parent: tag)),
        content: Matcher.options([
          Matcher.regex(r'\\(?:[0-9a-fA-F]{2}|\\)', tag: Tags.stringEscape),
          Matcher.regex(r'[^"\\]+'),
          // A non-escape backslash is ordinary content.
          // In particular, a quote after a backslash still closes the text.
          // LLVM uses `\22` for quotes.
          Matcher.verbatim(r'\'),
        ], tag: tag == Tags.doubleQuoteString ? Tags.stringContent : null),
        // Quoted names, like ordinary strings, can span lines.
        tag: tag,
      );

  /// Matches a complete LLVM token that matches the regex [pattern].
  static Matcher _bounded(String pattern, Tag tag) =>
      Matcher.regex('$_left(?:$pattern)$_right', tag: tag);

  /// Matches any of the literal [words] as a complete LLVM token.
  static Matcher _words(Set<String> words, Tag tag) =>
      _bounded(words.map(RegExp.escape).join('|'), tag);

  static final Matcher _numbers = Matcher.options([
    // LLVM 23 and later print special and
    // inexact floating-point values in these forms.
    _bounded(r'[+-](?:inf|qnan|s?nan\(0x[0-9a-fA-F]+\))', Tags.floatLiteral),
    _bounded(r'(?:f0x|0x[HKLMR]?)[0-9a-fA-F]+', Tags.floatLiteral),
    // Hexadecimal floats in C's %a format are only written by hand.
    _bounded(
      r'[+-]?0x(?:[0-9a-fA-F]+(?:\.[0-9a-fA-F]*)?|\.[0-9a-fA-F]+)'
      r'[pP][+-]?[0-9]+',
      Tags.floatLiteral,
    ),
    _bounded(r'[+-]?[0-9]+\.[0-9]*(?:[eE][+-]?[0-9]+)?', Tags.floatLiteral),
    _bounded(r'[us]0x[0-9a-fA-F]+|-?[0-9]+', Tags.integerLiteral),
  ]);
}
