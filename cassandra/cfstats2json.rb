#!/usr/lib64/fluent/ruby/bin/ruby 
require 'json'
 
result = {}
cur_ks = nil
cur_cf = nil
  
ARGF.each_line do |line|
  line.strip!
  if line =~ /^Keyspace: (.+)/
	cur_ks = $1
  	result[cur_ks] ||= {}
  elsif line =~ /^Column Family: (.+)/
  	cur_cf = $1
  	result[cur_ks]['cf'] ||= {}
  	result[cur_ks]['cf'][cur_cf] ||= {}
  elsif line =~ /^(Read Count|Read Latency|Write Count|Write Latency|Pending Tasks): (.+)/
  	if result[cur_ks][$1]
  		result[cur_ks]['cf'][cur_cf][$1] = $2
  	else
  		result[cur_ks][$1] = $2
  	end
  elsif line =~ /^(.+): (.+)$/
  	result[cur_ks]['cf'][cur_cf][$1] = $2
  end
end
puts JSON.pretty_generate(result)

