#!/usr/bin/env ruby

# ResourceOut is a no-op
class ResourceOut
  # No-op, just exits
  def run
    puts 'This resource does not have an out'
    exit 1
  end
end
