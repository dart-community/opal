# AGENTS.md

`package:opal` turns source text into tagged tokens for syntax highlighting.

## Goals

Opal aims to decently highlight the most common snippets of each language,
not to parse every program exactly.

- **Simplicity is core.**
  Grammars are lexical, not parsers.
  Classify tokens with simple, local rules,
  such as a name's casing or the token right next to it.
  If a rare construct needs its own special case,
  let it fall through to generic tokens.
  Removing support like that is a welcome change.
- **Readable first.**
  Prefer the form that is easy to read and maintain
  over one that is a few percent faster.
  Keep tokenizing linear in the input,
  and measure before making a performance claim.
- **Recover gracefully.**
  Snippets are often partial or invalid.
  An unclosed string shouldn't swallow the rest of the input,
  and malformed input should degrade to ordinary tokens.
- **Output changes are OK.**
  The package is pre-1.0 and experimental.
  Changed highlighting, breaking changes, and even rewriting a grammar
  are fine when they make Opal simpler or better.
  Note them in the changelog.
  Changing output by accident is what to catch.

## Working on a language

- **Test highlighting with goldens, not unit tests.**
  Add realistic snippets as `.in` files under `test/goldens/<language>/`
  and generate their `.out` files as `test/golden_test.dart` describes.
  Unit tests are for the matcher engine, registry, and tags.
- **Review the golden diff, not the test run.**
  Regenerating makes the tests pass by definition.
  Read `git diff test/goldens` and any newly created `.out` files,
  and check that each token is tagged the way a reader would expect.
  A change under a language you didn't mean to touch is a regression.
- **Goldens pin what Opal means to keep.**
  When a simplification drops support for something,
  delete the input lines that existed only to pin it.
- **Model new work on the newer grammars.**
- **Check current syntax.**
  For recent language features, consult the language's current reference
  instead of relying on memory.
- **Keep a language's names in step.**
  Its IDs and aliases appear in the registry, the registry test,
  the README list, and the changelog.

## Prose

- Break lines at natural phrase boundaries under 80 columns
  in doc comments and Markdown files, such as the changelog.
- Write comments as full sentences that say why:
  what an ordering protects or what malformed input a rule recovers from.
- Introduce examples with "such as" rather than "e.g.",
  and put code and language IDs in backticks.
- Word changelog entries like their neighbors under the top `-wip` heading,
  such as "Add support for Rust (`rust`, `rs`)."
- Write commit subjects as a short imperative sentence with no type prefix,
  such as "Improve and test HTML support".
