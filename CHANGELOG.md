## 0.1.1 (2026-05-27)

### Features

- add config schema combinator with validation and JSON Schema output
- add engine pipeline and replace action
- add CLI with watch/check/schema commands and config discovery
- implement pipe and exec actions with subprocess execution
- add 'service install' to generate a systemd/launchd unit
- log to stderr with configurable levels
- support pkl config files
- add 'eval' command to transform text through the pipeline

### Fixes

- stop the watch loop gracefully on SIGINT/SIGTERM
- rename replace action's "with" key to "replacement"
- xml-escape paths in launchd plist
- avoid clobbering a clipboard copy made during a slow hook
