require_relative 'database'
require_relative 'text_parser'
require_relative 'image_optimizer'

module Bbr
  class Builder
    def initialize(blog_root, system_root)
      @blog_root = blog_root
      @system_root = system_root
      
      # 各種パス
      @current_num_file = @blog_root.join('currentnum')
      @article_base_dir = @blog_root.join('article')
      @database_file = @blog_root.join('database.json')
    end

    def build(options)
      # 1. 対象記事の特定
      target_id = options[:id] || current_id
      unless target_id
        puts "エラー: 対象記事が特定できません。bbr set するか引数で指定してください。"
        exit 1
      end
      
      article_dir = @article_base_dir.join(target_id)
      src_file = article_dir.join("#{target_id}.m4")
      html_file = article_dir.join("html.html") # 出力先

      puts "=== 記事ビルド: #{target_id} ==="

      unless File.exist?(src_file)
        puts "エラー: ソースファイルが見つかりません: #{src_file}"
        exit 1
      end

      # 2. メタデータ抽出 & DB更新
      parser = TextParser.new(@blog_root)
      metadata = parser.extract_metadata(src_file)
      
      puts "  タイトル: #{metadata[:title]}"
      
      db = Database.new(@database_file)
      # DB更新 (force/update オプションはここで処理)
      db.update_record(target_id, metadata, options)

      # 3. 画像処理
      if options[:image_mode] == :normal
        optimizer = ImageOptimizer.new(article_dir, verbose: options[:verbose])
        optimizer.run(src_file, options[:force])
      else
        puts "  [IMG] 画像処理をスキップします (mode: #{options[:image_mode]})"
      end

      # 4. HTML生成
      # skip_image の場合は fatimage を直接参照するモードにする
      is_fat_mode = (options[:image_mode] == :fat)

      html_content = parser.convert(src_file, target_id, is_fat_mode)
      File.write(html_file, html_content)
      puts "  [HTML] 生成完了: #{html_file}"
    end

    private

    def current_id
      return nil unless File.exist?(@current_num_file)
      File.read(@current_num_file).strip
    end

  end
end
