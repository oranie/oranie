#!/opt/ruby-1.9.2/bin/ruby
# -*- encoding: utf-8 -*-

require 'rubygems'
require 'net/http'
require 'webrick'
require 'logger'

#ログ
log = Logger.new('/opt/logfile.log')
log.level = Logger::WARN

#デーモン化させ本プロセスを常駐させる。
Process.daemon

#指定したURLに1秒間隔で情報を取りに行き更新する。失敗したら終了。
class FileGet
    def get_start
        http = Net::HTTP.new("example.com", 80)
        http.open_timeout = 2
        http.read_timeout = 2
        req = Net::HTTP::Get.new('/sample.xml')
        loop {
            begin
                res = http.request(req)
                $body = res.body
                #S3へのアップ。時間が掛かるようなら別スレッドに。
                #exec("s3cmd put --acl-public --guess-mime-type ファイル名 s3://バケット名/パス/ファイル名")
                sleep(1)
            rescue => ex
                break
            end
        }
    end
end

#更新処理をスレッド化させ、エラー処理等を詰める。
begin
    t = FileGet.new
    ratadata_get = Thread.new do
        t.get_start
    end
    ratadata_get.join
rescue =>
    sleep(60)
    retry
end

#監視に利用する為のWebインターフェイスとして設定。
#FileGetスレッドが取得したオブジェクトを返すservlet
class ResponseServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, resp)
    resp.body = $body
    raise WEBrick::HTTPStatus::OK
  end
end

#404エラー用のservlet(apacheでやらせれば別にいらないかも)

#WEBrickサーバ処理部分
RateResponse = WEBrick::HTTPServer.new(
    :Port => 10080,
    :DocumentRoot   => '~/public_html/'
)

#/にservletをマウント
RateResponse.mount('/', ResponseServlet)



Signal.trap(:INT){Thread::list.each {|t| Thread::kill(t) if t != Thread::current}}
Signal.trap(:INT){exit(0)}

Signal.trap(:TERM){Thread::list.each {|t| Thread::kill(t) if t != Thread::current}}
Signal.trap(:TERM){exit(0)}

#サーバをスタート
RateResponse.start
