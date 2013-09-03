require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

module Kernel
  def fixme(*messages)
    #puts "FIX" "ME #{caller.first}:\n#{messages.inspect}"
    puts messages.inspect
    messages[0]
  end
end
