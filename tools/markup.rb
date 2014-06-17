#!/usr/bin/ruby -w

require_relative '../test/markup'

if ARGV.delete("--help")
  puts <<-HERE
Usage: ruby #{__FILE__} <programfile> <options>

Options:
  --help
  --no-indent
  --no-highlight
    HERE

  exit
end

options = {
  indent: !ARGV.delete("--no-indent"),
  highlight: !ARGV.delete("--no-highlight")
}

src = ARGF.read
sexp = Markup.parse_code(src)
markup = Markup.markup(src, Markup.parse_sexp(sexp), options)

puts sexp
puts "---"
puts markup
