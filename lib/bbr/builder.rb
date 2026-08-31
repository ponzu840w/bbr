require_relative 'database'
require_relative 'text_parser'
require_relative 'image_optimizer'
require_relative 'repository'

module Bbr
  class Builder
    def initialize(context)
      @context = context
      @repo = Repository.new(context)
    end

    def build(options)
      article = options[:id] ? @repo.find(options[:id]) : @repo.current
      unless article
        puts "エラー: 対象記事が特定できません。bbr set するか引数で指定してください。"
        exit 1
      end

      puts "=== 記事ビルド: #{article.id} ==="

      unless article.source_path.exist?
        puts "エラー: ソースファイルが見つかりません: #{article.source_path}"
        exit 1
      end

      # 1. メタデータ抽出 & DB更新
      parser = TextParser.new(@context.repo_root)
      metadata = parser.extract_metadata(article.source_path)

      puts "  タイトル: #{metadata[:title]}"

      db = Database.new(@context.database_path)
      db.update_record(article.id, metadata, options)

      # 2. 画像処理
      if options[:image_mode] == :normal
        optimizer = ImageOptimizer.new(article.path, verbose: options[:verbose])
        optimizer.run(article.source_path, options[:force])
      else
        puts "  [IMG] 画像処理をスキップします (mode: #{options[:image_mode]})"
      end

      # 3. HTML生成
      is_fat_mode = (options[:image_mode] == :fat)
      html_content = parser.convert(article.source_path, article.id, is_fat_mode)
      File.write(article.html_path, html_content)
      puts "  [HTML] 生成完了: #{article.html_path}"
    end
  end
end
