## ADDED Requirements

### Requirement: Alias command expansion
The `wsa` command SHALL map the first positional argument as alias and expand it to the configured target command template.

#### Scenario: Expand known alias
- **WHEN** user runs `wsa ab open` and config contains `ab agent-browser`
- **THEN** the system executes `agent-browser open`

### Requirement: Runtime argument merge
The system SHALL merge runtime arguments with configured command template using deterministic rules.

#### Scenario: Append runtime arguments when no placeholder
- **WHEN** user runs `wsa foo --ping` and config contains `foo foobar open`
- **THEN** the system executes `foobar open --ping`

### Requirement: Placeholder insertion with double dash
When command template contains standalone `--`, the system SHALL insert runtime arguments at that position instead of appending at tail.

#### Scenario: Insert runtime arguments into placeholder position
- **WHEN** user runs `wsa bar --age 40` and config contains `bar barbar -- --name ccwq`
- **THEN** the system executes `barbar --age 40 --name ccwq`

### Requirement: Unknown alias failure
The system SHALL fail with non-zero exit code when the provided alias does not exist in configuration.

#### Scenario: Reject unknown alias
- **WHEN** user runs `wsa unknown test`
- **THEN** the system prints an error for unknown alias and exits with non-zero code
