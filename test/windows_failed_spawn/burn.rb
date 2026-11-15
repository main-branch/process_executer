# frozen_string_literal: true

# CPU load for the freeze loop: spin for the given number of minutes, then exit.
# usage: ruby burn.rb [minutes]
stop = Time.now + (Integer(ARGV.fetch(0, '45')) * 60)
x = 0
x += 1 while Time.now < stop || ((x % 1_000_000).positive? && Time.now < stop)
