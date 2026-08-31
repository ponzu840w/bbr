require 'fileutils'

module Bbr
  class Server
    def initialize(context)
      @context = context
      @pid_file = context.system_root.join('.bbr_server.pid')
      @log_file = context.system_root.join('.bbr_server.log')
      @doc_root = context.repo_root.realpath.parent # blogディレクトリの親
      @port = 8000
    end

    # サーバー起動 (バックグラウンド)
    # 実際には bin/bbr _server を別プロセスで叩く
    def start_background
      if running?
        puts "サーバーは既に起動しています (PID: #{read_pid})"
        return
      end

      puts "プレビューサーバーを起動します..."
      
      # 自身のコマンドパスを取得
      bbr_bin = File.expand_path($0)
      
      # プロセス生成 (標準出力・エラーをログに逃がす)
      pid = spawn("ruby", bbr_bin, "_server", [:out, :err] => [@log_file.to_s, "w"])
      
      # PID保存
      File.write(@pid_file, pid)
      Process.detach(pid) # 子プロセスを切り離す

      # 起動待ち (簡易)
      sleep 1
      puts "起動しました (PID: #{pid}, Port: #{@port})"
    end

    # サーバー停止
    def stop
      unless running?
        puts "サーバーは起動していません。"
        return
      end

      pid = read_pid
      begin
        Process.kill("TERM", pid)
        puts "サーバーを停止しました (PID: #{pid})"
      rescue Errno::ESRCH
        puts "プロセスが見つかりませんでした。PIDファイルを削除します。"
      end
      
      cleanup
    end

    # サーバープロセスの実体 (bin/bbr _server から呼ばれる)
    def run_foreground
      require 'webrick' # prev 以外のコマンドを webrick 未導入でも動かすため遅延読み込み

      log = WEBrick::Log.new($stderr, WEBrick::Log::WARN)
      server = WEBrick::HTTPServer.new(
        Port: @port,
        DocumentRoot: @doc_root.to_s,
        AccessLog: [], # アクセスログは出さない
        Logger: log
      )

      trap 'INT' do server.shutdown end
      trap 'TERM' do server.shutdown end
      
      server.start
    end

    def open_browser(article_id)
      url = "http://localhost:#{@port}/blog/blog.html?id=#{article_id}"
      puts "Opening: #{url}"
      
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then system("start #{url}")
      when /darwin/             then system("open #{url}")
      when /linux/              then system("xdg-open #{url}")
      end
    end

    private

    def read_pid
      return nil unless File.exist?(@pid_file)
      File.read(@pid_file).to_i
    end

    def running?
      pid = read_pid
      return false unless pid
      
      # プロセス存在確認
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end

    def cleanup
      FileUtils.rm(@pid_file) if File.exist?(@pid_file)
    end
  end
end
