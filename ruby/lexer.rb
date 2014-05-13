#!/usr/bin/ruby -w

require "ripper"
require "pp"

ARGV.each do |p|
  f = File.read p
  puts
  pp Ripper.lex f
  puts
  pp Ripper.sexp_raw f
  puts
  pp Ripper.sexp f
end
