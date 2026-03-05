## ADDED Requirements

### Requirement: Ignore comments and blank lines
The configuration loader SHALL ignore blank lines and lines whose first non-space character is `#`.

#### Scenario: Skip non-effective lines
- **WHEN** config file includes blank lines and comment lines
- **THEN** only effective alias mapping lines are loaded

### Requirement: Alias line tokenization
Each effective config line SHALL be parsed as `<alias> <target...>`, where alias is first token and target command template is the remaining tokens.

#### Scenario: Parse alias and target template
- **WHEN** config line is `foo foobar open`
- **THEN** alias is parsed as `foo` and command template as `foobar open`

### Requirement: Config validation on load
The loader SHALL reject invalid config entries and return a non-zero exit code with actionable error message.

#### Scenario: Reject mapping without target command
- **WHEN** config line contains alias token but no target tokens
- **THEN** the system reports invalid mapping with line context and exits non-zero

### Requirement: Duplicate alias handling
The loader SHALL reject duplicate alias definitions to avoid ambiguous command expansion.

#### Scenario: Reject duplicate alias definitions
- **WHEN** the same alias appears on multiple effective lines
- **THEN** the system reports duplicate alias conflict and exits non-zero
