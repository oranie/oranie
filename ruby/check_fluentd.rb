#!/usr/local/rvm/rubies/ruby-1.9.3-p125/bin/ruby -Ku
#
#example: ./check_fluentd.rb  -f /var/log/td-agent/access_log.20120223 -h 127.0.0.1 -c 600 -w 180
#
require 'optparse'
require 'json'
require 'time'

opt = OptionParser.new
opts = Hash.new

opt.on('-f VAL' " Nagios check log file name") {|v| opts["logfile"] = v}
opt.on('-h VAL' " Check host_tag name") {|v| opts["host"] = v}
opt.on('-c VAL' " Check the time difference, or more if critical threshold (sec)") {|v| opts["critical"] = v}
opt.on('-w VAL' " Check the time difference, or more if warnings threshold (sec)") {|v| opts["warnings"] = v}

opt.parse!(ARGV)

def line_check(line,host_tag)
    if line =~ /#{host_tag}/
        return 0
    end
end

def log_line_parse(log_line)
    line_record = log_line.split(/\t/)
    return line_record
end

def tac_check(opts)
    log_file = opts["logfile"]
    host_tag = opts["host"]
    now_time = Time.new
    now_time = now_time.to_i
    critical_threshhold = (now_time - opts["critical"].to_i)
    warnings_threshhold = (now_time - opts["warnings"].to_i)
    
    open("|tac #{log_file}") do |fp|
        while line = fp.gets
            line_ary = log_line_parse(line) 
            log_time = Time.parse(line_ary[0])
            log_time = log_time.to_i
            #該当パラメータが出てくるまでに、ログの時間が閾値を越えると各処理を実行
            if log_time <= critical_threshhold 
                print  "Critical !!\nLAST LOG #{line}"
                exit 2
            elsif log_time <= warnings_threshhold
                if line_check(line,host_tag)
                    print  "Warnings!!!\n#{line}"
                    exit 1
                end
                next
            else
                if line_check(line,host_tag)
                    print  "OK!!\n#{line}"
                    exit 0
                end 
                next
            end
        end
        #最後まで読んでも該当パラメータが無い場合もcritical
        print  "Critical !!\nI read until the end...Not Found #{host_tag}\n"
        exit 2
    end
end

tac_check(opts)
