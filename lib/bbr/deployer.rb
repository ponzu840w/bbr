require 'net/ftp'
require 'io/console'
require 'fileutils'
require_relative 'repository'

module Bbr
  class Deployer
    SERVER = "ponzu840w.jp"
    USER = "web@ponzu840w.jp"

    def initialize(context)
      @context = context
      @repo = Repository.new(context)
      @database_file = context.database_path
      @tmp_dir = context.repo_root.join('tmp')

      FileUtils.mkdir_p(@tmp_dir)
    end

    def deploy(options)
      article = options[:id] ? @repo.find(options[:id]) : @repo.current
      unless article
        puts "エラー: 対象記事が特定できません。bbr set するか引数で指定してください。"
        return
      end

      unless article.html_path.exist?
        puts "エラー: HTMLファイルが見つかりません。先にビルドしてください: #{article.html_path}"
        return
      end

      puts "=== 記事デプロイ: #{article.id} ==="
      puts "Server: #{SERVER}"
      puts "User:   #{USER}"

      # パスワード入力
      print "FTP Password: "
      pass = STDIN.noecho(&:gets).chomp
      puts "\n"

      begin
        ftp = Net::FTP.new(SERVER)
        ftp.passive = true
        ftp.connect(SERVER, 21)
        ftp.login(USER, pass)
        ftp.binary = true

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
        ensure_remote_dir(ftp, article.id)
        ftp.chdir(article.id)

        # 5. HTMLアップロード
        print "  [Upload] html.html... "
        ftp.putbinaryfile(article.html_path, 'html.html')
        puts "OK"

        # 6. 画像アップロード
        ensure_remote_dir(ftp, 'image')
        ftp.chdir('image')

        if article.image_dir.exist?
          images = Dir.children(article.image_dir).reject { |f| f.start_with?('.') }

          if images.empty?
            puts "  [Image] No images to upload."
          else
            puts "  [Image] Uploading #{images.size} files..."
            images.each do |file|
              local_path = article.image_dir.join(file)
              next if File.directory?(local_path)

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

    # リモートディレクトリが存在することを確認（なければ作成）
    def ensure_remote_dir(ftp, dir_name)
      begin
        ftp.mkdir(dir_name)
      rescue Net::FTPPermError
        # 既に存在する(550)場合は無視
      end
    end
  end
end
