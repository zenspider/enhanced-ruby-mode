#!/usr/bin/ruby

require_relative 'erm_buffer'
# require "pp"

class ErmBuffer::Parser
  alias :old_realadd :realadd
  def realadd(sym,tok,len)
    x = old_realadd(sym, tok, len)
    p [sym, tok, len, self.ident_stack, self.indent_stack, self.brace_stack]
    # puts
    x
  end
end

# require "tracer"; Tracer.on

ARGV.each do |file|
  buf = ErmBuffer.new
  content = File.read file
  point_min, point_max, pbeg, len = 0, content.size, 0, content.size

  buf.add_content :x, point_min, point_max, pbeg, len, content

  puts buf.parse
end


# res=@res.map.with_index{|v,i| v ? "(#{i} #{v.join(' ')})" : nil}.flatten.join
# "((#{@src_size} #{@point_min} #{@point_max} #{@indent_stack.join(' ')})#{res})"

# ((264 0 264 l 36 r 44 d 205 e 212 b 217 l 222 r 227 e 261)
#  (0 34 47 186 187 199 205 207 212 215 217 220 221 222 231)
#  (4 1 34 47 186 187 199 231 261)
#  (9 221 222)
#  (10 205 207 212 215 217 220 261 264))

# ((src_size point_min point_max [indent_token indent_pos]...)
#  ...?)
