require 'open3'

module Bbr
  class TextParser
    def initialize(blog_root)
      @blog_root = blog_root
      @macro_file = @blog_root.join('html_article_define.m4')
    end

    # メタデータ (タイトル, カテゴリ, タグ) のみを抽出する
    def extract_metadata(src_path)
      extractor_macro = <<~M4
        define(_begin,`divert(0)TITLE:$1\nCAT:$2\nTAG:$3\ndivert(-1)')
        divert(-1)
      M4

      raw_content = File.read(src_path)
      output, stderr, status = Open3.capture3("m4", stdin_data: extractor_macro + raw_content)

      unless status.success?
        raise "Metadata extraction failed: #{stderr}"
      end

      data = {}
      output.each_line do |line|
        if line =~ /^TITLE:(.*)$/
          data[:title] = $1
        elsif line =~ /^CAT:(.*)$/
          data[:category] = $1
        elsif line =~ /^TAG:(.*)$/
          data[:tags] = $1.split(',').map(&:strip)
        end
      end
      data
    end

    # HTMLへの変換
    def convert(src_path, article_id, fat_image_mode = false)
      raw_content = File.read(src_path)
      
      # 記事ディレクトリのパスを取得 (m4実行時のカレントディレクトリ用)
      article_dir = File.dirname(src_path)

      # 1. 前処理: インデント処理、エスケープ、クオート挿入
      escaped_content = preprocess_escape(raw_content)

      # 2. 自動タグ付与
      tagged_content = process_auto_tags(escaped_content)

      # 3. m4 定義ファイルの準備
      macro_content = File.read(@macro_file)
      
      # -i オプション対応: 定義内の画像パスを置換
      if fat_image_mode
        macro_content = macro_content.gsub('image/', 'fatimage/')
      end

      # 記事番号定義
      artnum_def = "define(_artnum, #{article_id})dnl\n"

      # 4. m4 実行
      # 余計なcode_macro_defを削除し、純粋にマクロファイルとコンテンツを結合
      full_input = macro_content + "\n" + artnum_def + tagged_content
      
      # chdirオプションで、記事ディレクトリをカレントにして実行する
      output, stderr, status = Open3.capture3("m4", stdin_data: full_input, chdir: article_dir)
      
      if !status.success?
        # m4は警告(stderr)を出しても正常終了することがあるため、statusだけ見る
        # 致命的なエラーがあれば警告を表示
        puts "Warning: m4 stderr: #{stderr}" unless stderr.empty?
        # exit codeが0以外なら例外にする
        raise "m4 failed: #{stderr}" if status.exitstatus != 0
      end

      output
    end

    private

    # コードブロック処理
    def preprocess_escape(text)
      result = []
      state = :outer # :outer, :code_top, :in_code

      text.each_line do |line|
        # コードブロック終了判定
        if line.start_with?('_codeE')
          result << "]]]]]\n" + line
          state = :outer
          next
        end

        if state == :outer
          # lstripで改行コードごと消えてしまう空行を復元する
          stripped = line.lstrip
          if stripped.empty?
            result << "\n" # 空行または空白のみの行は、単なる改行として出力
          elsif stripped.start_with?('_code')
            state = :code_top
            result << stripped
          else
            result << stripped
          end
        else
          # コードブロック内
          escaped = line.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

          if state == :code_top
            result << "\n[[[[[" + escaped
            state = :in_code
          else
            result << escaped
          end
        end
      end
      
      result.join
    end

    # 自動タグ付与
    def process_auto_tags(text)
      result = []
      state = :outer
      nest = 0
      
      p_child_regex = /^_(a|img|br|inyo)/

      text.each_line do |line|
        chomp_line = line.chomp

        if chomp_line.strip.empty?
          if state == :p
            result << "</p>"
            state = :outer
          elsif state == :code
            result << chomp_line
          end
          next
        end

        is_macro = chomp_line.start_with?('_')
        is_p_child = chomp_line =~ p_child_regex
        
        if !is_macro || is_p_child
          if state == :list
            result << "<li>#{chomp_line}"
          elsif state != :p && state != :code
            state = :p
            result << "<p>"
            result << chomp_line
          else
            result << chomp_line
          end
        else
          if state == :p
            result << "</p>"
            state = :outer
          end

          if chomp_line =~ /^_(123|kajo)([^E]|$)/
            state = :list
            nest += 1
          elsif chomp_line =~ /^_code([^E]|$)/
            state = :code
          end

          result << chomp_line

          if chomp_line =~ /^_(123|kajo)E/ && state != :code
            nest -= 1
            state = :outer if nest <= 0
          elsif state == :code && chomp_line =~ /^_codeE/
            state = :outer
          end
        end
      end
      
      result << "</p>" if state == :p
      result.join("\n")
    end
  end
end
