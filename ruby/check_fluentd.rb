#!/usr/local/rvm/rubies/ruby-1.9.3-p125/bin/ruby 
#
#example: ./check_fluentd.rb -p /var/log/td-agent/ -f access_log -h 127.0.0.1 -c 600 -w 180
#
#該当ログファイルを読んでいって、閾値を超えるまでに-sオプションで指定した文字列が出現するかどうかで監視します

require 'optparse'
require 'time'

opt = OptionParser.new
opts = Hash.new

opt.on('-p VAL' " Nagios check log file path") {|v| opts["log_path"] = v}
opt.on('-f VAL' " Nagios check log file name") {|v| opts["file_name"] = v}
opt.on('-s VAL' " Check check string ") {|v| opts["str"] = v}
opt.on('-c VAL' " Check the time difference, or more if critical threshold (sec)") {|v| opts["critical"] = v}
opt.on('-w VAL' " Check the time difference, or more if warnings threshold (sec)") {|v| opts["warnings"] = v}

opt.parse!(ARGV)

def get_new_logfile(path,logfile)
    cmd = "find #{path} -name \"#{logfile}*\"| xargs ls -t| head -n 1"
    new_log_file = open("|#{cmd}")do |fp|
        new_log_file = fp.gets
    end
    File.exist?("#{new_log_file.chomp}")
    return new_log_file.chomp
end

def line_check(log_line,check_str)
    if log_line =~ /#{check_str}/
        return true
    end
    return false
end

def log_line_parse(log_line)
    line_record = log_line.split(/\t/)
    return line_record
end

def tac_check(opts)
    log_file  = opts["log_file"]
    check_str = opts["str"]
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
                print  "Critical !!\nLAST LOG #{log_file}\n #{line}"
                exit 2
            elsif log_time <= warnings_threshhold
                if line_check(line,check_str)
                    print  "Warnings!!!\n #{log_file}\n #{line}"
                    exit 1
                end
                next
            else
                if line_check(line,check_str)
                    print  "OK!!\n #{line}"
                    exit 0
                end 
                next
            end
        end
        #最後まで読んでも該当パラメータが無い場合もcritical
        print  "Critical !!\nI read until the end...Not Found #{log_file}\n #{check_str}\n"
        exit 2
    end
end

begin
    opts["log_file"] = get_new_logfile(opts["log_path"],opts["file_name"])
    tac_check(opts)
rescue => evar
   raise  "ERROR!!! #{evar}"
end
