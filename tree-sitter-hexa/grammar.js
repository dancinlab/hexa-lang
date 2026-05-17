/**
 * tree-sitter grammar for hexa-lang — practical (highlight-grade).
 *
 * hexa is a full native-compiled language; a complete AST grammar is a
 * large undertaking. This is a deliberate PRACTICAL grammar: a flat
 * token stream (comment / string / char / number / annotation / keyword
 * / builtin / identifier / operator / punctuation, with a single-char
 * `other` catch-all). It parses ANY .hexa file with 0 ERROR and exposes
 * every lexical class for queries/highlights.scm — enough for editor
 * highlighting (Neovim / Helix / Zed / Emacs) and GitHub. It is NOT a
 * structural parse tree; the compiler's own parser owns that.
 *
 * Token set mirrors editor/vscode/syntaxes/hexa.tmLanguage.json.
 */
module.exports = grammar({
  name: 'hexa',

  extras: $ => [/\s/],

  word: $ => $.identifier,

  rules: {
    source_file: $ => repeat($._token),

    _token: $ => choice(
      $.comment,
      $.string,
      $.char,
      $.number,
      $.annotation,
      $.keyword,
      $.builtin,
      $.identifier,
      $.operator,
      $.punctuation,
      $.other,
    ),

    comment: $ => token(choice(
      seq('//', /[^\n]*/),
      seq('/*', /[^*]*\*+([^/*][^*]*\*+)*/, '/'),
    )),

    string: $ => token(seq('"', /(\\.|[^"\\\n])*/, '"')),

    char: $ => token(seq("'", /(\\[nrt\\'0]|[^'\\])/, "'")),

    number: $ => token(choice(
      /\d[\d_]*\.\d[\d_]*([eE][+-]?\d+)?/,
      /0[xX][0-9a-fA-F_]+/,
      /\d[\d_]*/,
    )),

    annotation: $ => token(seq('@', /[a-zA-Z_][a-zA-Z0-9_]*/)),

    keyword: $ => choice(
      // control
      'if', 'else', 'match', 'for', 'while', 'loop', 'return',
      'yield', 'break', 'continue',
      // declaration
      'fn', 'let', 'mut', 'const', 'static', 'type', 'struct',
      'enum', 'trait', 'impl',
      // other
      'mod', 'use', 'pub', 'crate', 'own', 'borrow', 'move', 'drop',
      'spawn', 'channel', 'select', 'atomic', 'effect', 'handle',
      'resume', 'import', 'as', 'in', 'and', 'or', 'not', 'self',
      // literals
      'true', 'false', 'void',
    ),

    builtin: $ => choice(
      'print', 'println', 'len', 'type_of', 'sigma', 'phi', 'tau',
      'gcd', 'sopfr', 'read_file', 'write_file', 'file_exists', 'keys',
      'str', 'int', 'float', 'bool', 'char', 'byte', 'any', 'array',
      'map', 'chr', 'ord', 'substr', 'split',
    ),

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    operator: $ => token(choice(
      '==', '!=', '<=', '>=', '<', '>', '&&', '||', '!', '^^',
      '**', '+', '-', '*', '/', '%', '&', '|', '^', '~',
      ':=', '=', '->', '...', '..=', '..',
    )),

    punctuation: $ => choice('{', '}', '(', ')', '[', ']', ',', ';', ':', '.'),

    other: $ => token(prec(-1, /./)),
  },
});
