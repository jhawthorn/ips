# IPS

![demo](demo.gif)

## Installation

```bash
gem install ips
```

## Usage

### Library

```ruby
require "ips"

IPS.run do |x|
  x.report("split/join") { "hello world".split(" ").join("-") }
  x.report("gsub")       { "hello world".gsub(" ", "-") }
end
```

### CLI

```
$ ips -e '"hello world".split(" ").join("-")' -e '"hello world".gsub(" ", "-")'
```

Compare across Ruby versions:

```
$ ips --ruby 3.4 --ruby 4.0 -e 'Object.new'
```

Compare across Ruby versions, arguments, and commands:

```
$ ips --ruby '3.4' --ruby '3.4 --yjit' --ruby '4.0' --ruby '4.0 --yjit' -e 'Object.new' -e 'Object.allocate'
```

Compare the same benchmark across commits of the current repository:

```
$ ips --sha HEAD~3 --sha HEAD~10..HEAD~5 bench.rb
```

Each commit is checked out in place with `git checkout --detach`, so the Ruby,
the bundle, and any per-directory setup stay identical across every commit. The
working tree must be clean, and the branch you started on is restored when the
run finishes (or is interrupted).

To share results in a pull request or issue, add `--markdown`. The usual
report still prints to stderr, and stdout gets only markdown: a results
table, then collapsed sections with the benchmark code and the environment
(the command, `RUBY_DESCRIPTION`, the ips version). You can copy it from the
terminal or pipe it to your clipboard:

```
$ ips --markdown --sha main bench.rb | pbcopy
```

````markdown
| Benchmark | Commit           |      i/s |    ± | vs `main (b73c1da)`      |
| :-------- | :--------------- | -------: | ---: | :----------------------- |
| `work`    | `main (b73c1da)` | 626.752k | 1.1% | baseline                 |
|           | `feature`        |  23.538M | 1.0% | **37.55 ± 0.54× faster** |
| `noop`    | `main (b73c1da)` |  62.442M | 0.9% | baseline                 |
|           | `feature`        |  66.992M | 2.8% | **1.07 ± 0.03× faster**  |

<details><summary>Benchmark code</summary>

`bench.rb`

```ruby
require_relative "lib"
IPS.run { |x| x.report("work") { work }; x.report("noop") { } }
```

</details>

<details><summary>Environment</summary>

```console
$ ips --markdown -t 1 --sha main bench.rb
```

- `ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]`
- ips 0.5.0

</details>
````

Each row is compared against the first variant: the first `--sha` commit
(so the current checkout reads as "faster" or "slower" than `main`), or the
first `--ruby` otherwise. With a single variant, benchmarks are compared
against the fastest. A difference is only called faster or slower when it's
larger than the error.

The collapsed code is the script file (each version, if it differs between the
`--sha` commits) and any `--prelude`, or for `-e` the equivalent `IPS.run`,
which can be rerun with plain `ruby`.

From the library, `IPS.run` returns a result that responds to `to_markdown`.

Besides Ruby scripts that use IPS, `ips` can run YAML benchmark definitions
and plain scripts:

```
$ ips bench.yml
$ ips script.rb
```

A `.yml` file has a `prelude`, a `benchmark` (a single expression, a
`name: expression` mapping, or a list of `name`/`script`/`prelude` entries) and
an optional `teardown`. Each benchmark is run as a report and can see the local
variables defined by the prelude. A Ruby script that doesn't use IPS is
benchmarked as a whole.

Scripts written for the [benchmark-ips](https://github.com/evanphx/benchmark-ips)
gem (`require "benchmark/ips"` and `Benchmark.ips`) can be run with the CLI.

`ips` picks how to load a file from its extension and contents. Use `--loader`
to say so explicitly when it guesses wrong:

- `auto` — the default: `yaml` for `.yml`/`.yaml`, otherwise `program` if the file looks like it uses IPS or benchmark-ips, else `snippet`
- `snippet` — benchmark the whole file as one report
- `program` — load the file as-is; it calls `IPS.run` (or `Benchmark.ips`) itself
- `yaml` — a benchmark_driver style definition

Options:

- `--ruby VERSION` — run against a specific Ruby (repeatable)
- `--sha REV` — also run against a commit of the current repo (repeatable; a `A..B` range expands to its commits, oldest first)
- `-e CODE` — inline benchmark expression (repeatable)
- `--prelude CODE` — run setup code before the benchmark (repeatable)
- `--loader LOADER` — how to load the file: `auto`, `snippet`, `program` or `yaml` (default: `auto`)
- `-I DIR` — add a directory to the load path (repeatable)
- `-t SECONDS` — benchmark time (default: 5)
- `-w SECONDS` — warmup time (default: 20% of benchmark time)
- `--save PATH` — save results to JSON (appends to existing file)
- `--markdown` — print results as a markdown table on stdout (the usual output moves to stderr)
- `--debug` — show compiled source, cycle counts, and per-batch timing
- `--yjit`, `--zjit`, `--disable-gems` — passed through to Ruby
- `-r LIB` — require a library before running

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jhawthorn/ips. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jhawthorn/ips/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the IPS project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jhawthorn/ips/blob/main/CODE_OF_CONDUCT.md).
