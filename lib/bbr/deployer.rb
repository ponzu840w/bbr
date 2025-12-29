require 'net/ftp'
require 'io/console'
require 'fileutils'

module Bbr
  class Deployer
    # 元スクリプトの設定値を移植
    SERVER = "ponzu840w.jp"
    USER = "web@ponzu840w.jp"

    def initialize(blog_root)
      @blog_root = blog_root
      @database_file = @blog_root.join('database.json')
      @tmp_dir = @blog_root.join('tmp')
      @current_num_file = @blog_root.join('currentnum')
      
      # バックアップ用ディレクトリ作成
      FileUtils.mkdir_p(@tmp_dir)
    end

    def deploy(options)
      id = options[:id] || current_id
      unless id
        puts "エラー: 対象記事が特定できません。bbr set するか引数で指定してください。"
        return
      end

      article_dir = @blog_root.join('article', id)
      html_file = article_dir.join('html.html')
      image_dir = article_dir.join('image')

      unless File.exist?(html_file)
        puts "エラー: HTMLファイルが見つかりません。先にビルドしてください: #{html_file}"
        return
      end

      puts "=== 記事デプロイ: #{id} ==="
      puts "Server: #{SERVER}"
      puts "User:   #{USER}"

      # パスワード入力
      print "FTP Password: "
      pass = STDIN.noecho(&:gets).chomp
      puts "\n"

      begin
        ftp = Net::FTP.new(SERVER)
        ftp.passive = true # 最近の環境ではパッシブモード推奨
        ftp.connect(SERVER, 21)
        ftp.login(USER, pass)
        ftp.binary = true # バイナリモード必須
        
        puts "Connected."

        # 1. ディレクトリ移動
        ftp.chdir('blog/')

        # 2. データベースのバックアップ (ダウンロード)
        backup_filename = "database_#{Time.now.to_i}.json"
        local_backup_path = @tmp_dir.join(backup_filename)
        
        print "  [Backup] Downloading database.json... "
        begin
          ftp.getbinaryfile('database.json', local_backup_path)
          puts "OK -> #{local_backup_path.basename}"
        rescue Net::FTPPermError
          puts "Skipped (Remote DB not found?)"
        end

        # 3. データベースのアップロード
        if File.exist?(@database_file)
          print "  [Upload] Uploading database.json... "
          ftp.putbinaryfile(@database_file, 'database.json')
          puts "OK"
        else
          puts "  [Upload] Warning: Local database.json not found."
        end

        # 4. 記事ディレクトリへ移動 (なければ作成)
        ftp.chdir('article/')
        ensure_remote_dir(ftp, id)
        ftp.chdir(id)

        # 5. HTMLアップロード
        print "  [Upload] html.html... "
        ftp.putbinaryfile(html_file, 'html.html')
        puts "OK"

        # 6. 画像アップロード
        ensure_remote_dir(ftp, 'image')
        ftp.chdir('image')

        if Dir.exist?(image_dir)
          # ローカルの画像一覧を取得 (隠しファイル除く)
          images = Dir.children(image_dir).reject { |f| f.start_with?('.') }
          
          if images.empty?
            puts "  [Image] No images to upload."
          else
            puts "  [Image] Uploading #{images.size} files..."
            images.each do |file|
              local_path = image_dir.join(file)
              next if File.directory?(local_path) # ディレクトリはスキップ

              ftp.putbinaryfile(local_path, file)
              puts "    -> #{file}"
            end
          end
        end

        puts "デプロイ完了"

      rescue Net::FTPError => e
        puts "\nFTP Error: #{e.message}"
      ensure
        ftp.close if ftp && !ftp.closed?
      end
    end

    private

    def current_id
      return nil unless File.exist?(@current_num_file)
      File.read(@current_num_file).strip
    end

    # リモートディレクトリが存在することを確認（なければ作成）
    def ensure_remote_dir(ftp, dir_name)
      # nlst や list はサーバーによって挙動が違うので、
      # 強引に mkdir してエラーなら無視する方式が一番確実です
      begin
        ftp.mkdir(dir_name)
        # puts "    Created directory: #{dir_name}"
      rescue Net::FTPPermError
        # 既に存在する(550)場合は無視
      end
    end
  end
end
