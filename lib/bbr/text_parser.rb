require 'open3'

module Bbr
  class TextParser
    def initialize(blog_root)
      @blog_root = blog_root
      @macro_file = @blog_root.join('html_article_define.m4')
    end

    # メタデータ (タイトル, カテゴリ, タグ) のみを抽出する
    # 元スクリプトの `define(_begin, ...)` ハックの再現
    def extract_metadata(src_path)
      extractor_macro = <<~M4
        define(_begin,`divert(0)TITLE:$1\nCAT:$2\nTAG:$3\ndivert(-1)')
        divert(-1)
      M4

      # エスケープ処理などはせず、単純にマクロ展開して情報を抜く
      raw_content = File.read(src_path)
      output, stderr, status = Open3.capture3("m4", stdin_data: extractor_macro + raw_content)

      unless status.success?
        raise "Metadata extraction failed: #{stderr}"
      end

      # 解析
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

    # HTMLへの変換 (AWKの魔術をRubyへ移植)
    def convert(src_path, article_id, fat_image_mode = false)
      raw_content = File.read(src_path)

      # 1. 前処理 (Escape): コードブロック内の退避
      escaped_content = preprocess_escape(raw_content)

      # 2. 自動タグ付与 (AWKロジックの移植: m4展開前に <p>, <li> を入れる)
      tagged_content = process_auto_tags(escaped_content)

      # 3. m4 定義ファイルの準備
      # 画像パスの置換設定 (fatimageモードの場合)
      path_sed = fat_image_mode ? "define(_fatmode,1)" : "define(_fatmode,0)"
      
      # 記事番号定義
      artnum_def = "define(_artnum, #{article_id})dnl\n"

      # 4. m4 実行
      # 定義ファイル + 記事ソース を結合
      full_input = path_sed + "\n" + File.read(@macro_file) + "\n" + artnum_def + tagged_content
      
      output, stderr, status = Open3.capture3("m4", stdin_data: full_input)
      raise "m4 failed: #{stderr}" unless status.success?

      output
    end

    private

    # _code ブロック内のインデント削除とエスケープ
    def preprocess_escape(text)
      in_code = false
      result = []

      # マクロ定義を埋め込む (コードブロック保護用)
      # 元スクリプトの `code_escaper` 相当
      code_macro_start = "define(_code,`changequote(`[[[[[',`]]]]]')')\n"
      code_macro_end   = "define(_codeE,`changequote(`,'\'')'\'')\n"
      
      # 実際のテキスト処理
      text.each_line do |line|
        # コードブロック判定
        if line =~ /^_code(?!E)/
          in_code = true
          result << "\n[[[[[" + line # マクロ引数として認識させるためのクオート開始
          next
        end

        if line =~ /^_codeE/
          in_code = false
          result << line.chomp + "]]]]]\n" # クオート終了
          next
        end

        if in_code
          # コードブロック内: HTMLエスケープ & インデント削除不可(元スクリプトは削除していたが、今回はそのままにするか、要調整)
          # 元スクリプトのAWK一段目: `match($0,/^[ \t]*/); noid=substr($0,RLENGTH+1)` -> インデント削除
          stripped = line.sub(/^[ \t]*/, '')
          escaped = stripped.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
          result << escaped
        else
          # 通常行
          result << line
        end
      end
      
      code_macro_start + code_macro_end + result.join
    end

    # AWKの自動タグ付与ロジックの移植
    def process_auto_tags(text)
      result = []
      state = :outer # :outer, :p, :list, :code
      nest = 0
      
      # インライン扱いするマクロ (これらで始まっても <p> を閉じない)
      p_child_regex = /^_(a|img|br|inyo)/ # _inyo (blockquote) は元定義だと微妙だが、一旦インライン扱いしないとpに入らないかも

      text.each_line do |line|
        line = line.chomp

        # 空行処理
        if line.strip.empty?
          if state == :p
            result << "</p>"
            state = :outer
          elsif state == :code
            result << line
          end
          next
        end

        # 行の種類判定
        is_macro = line.start_with?('_')
        is_p_child = line =~ p_child_regex
        
        # 「ストレートな行」: マクロでない、またはインラインマクロ
        if !is_macro || is_p_child
          if state == :list
            result << "<li>#{line}" # 閉じタグ </li> はブラウザ任せ(元スクリプトの挙動)または改行で入れる
          elsif state != :p && state != :code
            state = :p
            result << "<p>"
            result << line
          else
            result << line
          end
        else
          # ブロック要素など (<p>に含めるのが不適当な行)
          if state == :p
            result << "</p>"
            state = :outer
          end

          # リスト開始判定
          if line =~ /^_(123|kajo)([^E]|$)/
            state = :list
            nest += 1
          # コード開始
          elsif line =~ /^_code([^E]|$)/
            state = :code
          end

          result << line

          # リスト終了判定
          if line =~ /^_(123|kajo)E/ && state != :code
            nest -= 1
            state = :outer if nest <= 0
          # コード終了
          elsif state == :code && line =~ /^_codeE/
            state = :outer
          end
        end
      end
      
      result << "</p>" if state == :p
      result.join("\n")
    end
  end
end
