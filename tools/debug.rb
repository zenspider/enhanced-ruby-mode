#!/usr/bin/ruby

require_relative '../ruby/erm_buffer'

class ErmBuffer::Parser
  alias :old_realadd :realadd
  def realadd(sym,tok,len)
    x = old_realadd(sym, tok, len)
    p [sym, tok, len]
    x
  end
end

# require "tracer"; Tracer.on

ARGV.each do |file|
  buf = ErmBuffer.new
  content = File.read file
  point_min, point_max, pbeg, len = 1, content.size+1, 0, content.size

  buf.add_content :x, point_min, point_max, pbeg, len, content

  puts buf.parse
end
