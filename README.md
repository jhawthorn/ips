# IPS

A Ruby benchmarking tool that measures iterations per second with statistical analysis, automatic warmup, and comparison summaries.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add ips
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install ips
```

## Usage

```ruby
require "ips"

IPS.run do |x|
  x.report("addition")       { 1 + 1 }
  x.report("multiplication") { 2 * 3 }
  x.report("wtf") { eval("#{1.to_s} + #{1.to_s}") }
end
```

Output:

```
            addition:    45.759M i/s (± 1.2%)
      multiplication:    45.593M i/s (± 0.2%)
                 wtf:   463.420k i/s (± 0.9%, GC  6.3%)

Summary
  addition ran
    1.00 ± 0.01 times faster than multiplication
    98.74 ± 1.49 times faster than wtf
```

When two or more items are reported, a comparison summary is automatically displayed.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jhawthorn/ips. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jhawthorn/ips/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the IPS project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jhawthorn/ips/blob/main/CODE_OF_CONDUCT.md).
