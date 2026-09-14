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

Options:

- `--ruby VERSION` — run against a specific Ruby (repeatable)
- `--sha REV` — also run against a commit of the current repo (repeatable; a `A..B` range expands to its commits, oldest first)
- `-e CODE` — inline benchmark expression (repeatable)
- `--prelude CODE` — run setup code before the benchmark (repeatable)
- `-I DIR` — add a directory to the load path (repeatable)
- `-t SECONDS` — benchmark time (default: 5)
- `-w SECONDS` — warmup time (default: 20% of benchmark time)
- `--save PATH` — save results to JSON (appends to existing file)
- `--debug` — show compiled source, cycle counts, and per-batch timing
- `--yjit`, `--zjit`, `--disable-gems` — passed through to Ruby
- `-r LIB` — require a library before running

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jhawthorn/ips. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jhawthorn/ips/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the IPS project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jhawthorn/ips/blob/main/CODE_OF_CONDUCT.md).
