#!/usr/bin/env ruby

require_relative "erm_buffer"

STDIN.set_encoding "UTF-8"

class BufferStore
  def initialize
    @buffers = {}
  end

  def get_buffer buf_num
    @buffers[buf_num] ||= ErmBuffer.new if buf_num > 0
  end

  def rm buf_num
    @buffers.delete buf_num
  end
end

store = BufferStore.new

EOT = "\n\0\0\0\n"

begin
  while c = STDIN.gets(EOT)
    cmd  = c[0].to_sym
    args = c[1..-6].split ":", 6
    bn   = args.shift.to_i
    buf  = store.get_buffer bn

    case cmd
    when :x then
      (buf || ErmBuffer).set_extra_keywords args.first.split " "
    when :c then
      STDERR.print "c"
      STDERR.puts "#{buf.check_syntax}\n\n\0\0\0"
    when :k then
      store.rm bn
    else
      buf.add_content(cmd, *args) unless cmd == :g

      unless cmd == :a
        STDERR.puts buf.parse
        STDERR.puts "\0\0\0"
      end
    end
  end
rescue
  STDERR.puts "e#{$!.message}: #{$!.backtrace.join("\n")}#{EOT}"
end
