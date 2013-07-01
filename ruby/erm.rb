#!/usr/bin/env ruby

class BufferStore
  def initialize
    @buffers={}
  end

  def get_buffer(buf_num)
    if buf_num > 0
      @buffers[buf_num] || @buffers[buf_num]=ErmBuffer.new
    end
  end

  def rm(buf_num)
    @buffers.delete(buf_num)
  end
end

# module Kernel
#   def fixme(*args)
#     $fixme.puts args.inspect
#     $fixme.flush
#   end
# end

STDIN.set_encoding("UTF-8")

# $fixme=File.open("/tmp/erm.out",'w')
# $fixme.puts "\n\nstarting\n\n"
# $fixme.flush

require_relative 'erm_buffer'

store=BufferStore.new
begin
  while c=STDIN.gets("\n\0\0\0\n")
    # fixme c
    cmd=c[0].to_sym
    args=c[1..-6].split(':',6)
    buf=store.get_buffer(bn=args.shift.to_i)
    case cmd
    when :x
      (buf || ErmBuffer).set_extra_keywords(args.first.split(' '))
    when :c
      STDERR.print 'c'
      STDERR.puts "#{buf.check_syntax}\n\n\0\0\0"
    when :k
      store.rm(bn)
      # $fixme.puts "Killed"
    else
      buf.add_content(cmd,*args) unless cmd == :g
      unless cmd == :a
        r=buf.parse
        # fixme r
        STDERR.puts(r << "\n\0\0\0")
      end
    end
    # $fixme.puts buf.buffer
    # $fixme.flush
  end
rescue
  # $fixme.puts c.inspect
  # $fixme.puts $!.message
  # $fixme.puts $!.backtrace
  # $fixme.flush
  STDERR.puts "e#{$!.message}: #{$!.backtrace.join("\n")}\n\0\0\0\n"
end
