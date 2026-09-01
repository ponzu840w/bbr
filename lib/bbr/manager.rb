require 'fileutils'
require_relative 'article'
require_relative 'repository'
require_relative 'database'
require_relative 'text_parser'

module Bbr
  class Manager
    def initialize(context)
      @context = context
      @repo = Repository.new(context)
    end

    def show_status
      article = @repo.current
      unless article
        puts "現在選択されている記事はありません。"
        return
      end

      id = article.id
      puts "=== BBR Status [#{id}] ==="

      # 1. タイトル取得 (m4がある場合)
      if article.source_path.exist?
        begin
          parser = TextParser.new(@context)
          meta = parser.extract_metadata(article.source_path)
          puts "Title:    #{meta[:title]}"
        rescue => e
          puts "Title:    (Error reading title: #{e.message})"
        end
      else
        puts "Title:    (Source file not found)"
      end

      puts "Path:     #{article.path}"
      puts ""

      # 2. データベース状況
      puts "[Database]"
      db = Database.new(@context.database_path)
      record = db.get_record(id)

      db_time = nil
      if record
        db_time = Time.at(record[:time])
        puts "  Status: \e[32mRELEASED\e[0m"
        puts "  Time:   #{db_time.strftime('%Y-%m-%d %H:%M:%S')} (#{record[:time]})"
      else
        puts "  Status: \e[31mNOT REGISTERED (Draft)\e[0m"
      end
      puts ""

      # 3. ビルド状況
      puts "[Build]"
      if article.html_path.exist?
        html_mtime = File.mtime(article.html_path)
        puts "  HTML:   Exists (#{html_mtime.strftime('%Y-%m-%d %H:%M:%S')})"

        if db_time
          if html_mtime > db_time
            puts "  State:  \e[33mDIRTY (HTML is newer than DB)\e[0m"
          else
            puts "  State:  \e[32mCLEAN\e[0m"
          end
        end
      else
        puts "  HTML:   \e[31mNot found\e[0m"
      end
      puts ""

      # 4. 画像状況
      puts "[Images]"
      fat_count = article.fat_image_dir.exist? ? Dir.children(article.fat_image_dir).reject { |f| f.start_with?('.') }.size : 0
      img_count = article.image_dir.exist?     ? Dir.children(article.image_dir).reject     { |f| f.start_with?('.') }.size : 0

      puts "  Source: #{fat_count} files (fatimage)"
      puts "  Output: #{img_count} files (image)"

      if fat_count == img_count
        puts "  State:  \e[32mOK\e[0m"
      else
        puts "  State:  \e[33mMISMATCH (Run 'bbr build' to optimize)\e[0m"
      end
    end

    # 指定した番号をセットする (bbr set ID)
    def set_article(id)
      article = @repo.find(id)
      unless article.exists?
        puts "エラー: 記事ディレクトリ #{article.id} が見つかりません。"
        exit 1
      end

      @repo.set_current(article)
      update_symlink(article.path)

      puts "記事 #{article.id} をセットしました。"
    end

    # 新規記事を作成してセットする (bbr new)
    def create_new
      new_id = @repo.next_id
      new_dir = @context.articles_dir.join(new_id)

      puts "新規記事 #{new_id} を作成します..."

      FileUtils.mkdir_p([
        new_dir,
        new_dir.join('image'),
        new_dir.join('fatimage')
      ])

      m4_path = new_dir.join("#{new_id}.m4")
      unless m4_path.exist?
        File.write(m4_path, "_begin(タイトル,category,`tag1,tag2')\n\n本文\n")
      end

      set_article(new_id)
    end

    # 記事をエディタで開く
    def edit_article
      article = @repo.current
      unless article
        puts "エラー: 作業中の記事が設定されていません。'bbr set <ID>' を実行してください。"
        return
      end

      unless article.source_path.exist?
        puts "エラー: ファイルが見つかりません: #{article.source_path}"
        return
      end

      editor = ENV['EDITOR'] || 'vim'
      system(editor, article.source_path.to_s)
    end

    # 現在の記事パスを返す (bbr pwd 用)
    def get_current_path
      article = @repo.current
      return nil unless article && article.path.directory?
      article.path
    end

    # ファイラーで開く (bbr dir 用)
    def open_directory
      path = get_current_path
      unless path
        puts "エラー: 現在選択されている記事がありません。"
        return
      end

      puts "Opening: #{path}"
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then system("explorer \"#{path}\"") # Windows
      when /darwin/             then system("open \"#{path}\"")     # macOS
      when /linux/              then system("xdg-open \"#{path}\"") # Linux
      end
    end

    private

    # ルートにある 'art' リンクを更新（旧互換のため Manager 側に残す）
    def update_symlink(target_path)
      link_path = @context.system_root.join('art')
      FileUtils.rm(link_path) if File.symlink?(link_path) || File.exist?(link_path)
      FileUtils.ln_s(target_path, link_path)
    end
  end
end
