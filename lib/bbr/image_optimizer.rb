require 'fileutils'
require 'open3'
require 'set'

module Bbr
  class ImageOptimizer
    def initialize(article_dir)
      @fat_dir = article_dir.join('fatimage')
      @out_dir = article_dir.join('image')
      FileUtils.mkdir_p(@out_dir)
    end

    def run(src_path, force = false)
      puts "  [IMG] 画像最適化を開始します..."
      
      # m4を使って画像リストを抽出
      # _img(filename, alt, size_opt, color_opt) -> filename \t size_opt \t color_opt
      extractor_macro = <<~M4
        define(_img,`divert(0)$1\t$3\t$4\ndivert(-1)')
        divert(-1)
      M4

      # m4実行 (include解決のため、記事ディレクトリをカレントにする)
      article_dir = File.dirname(src_path)
      raw_content = File.read(src_path)
      
      # 【修正】ここは magick m4 ではなく、純粋な m4 コマンドを呼ぶ
      output, stderr, status = Open3.capture3("m4", stdin_data: extractor_macro + raw_content, chdir: article_dir)

      unless status.success?
        puts "  [IMG] 警告: 画像リスト抽出中にm4のエラーが発生しました: #{stderr}"
      end

      # 重複処理回避用
      processed = Set.new

      output.each_line do |line|
        line.strip!
        next if line.empty?
        
        filename, size_opt, color_opt = line.split("\t")
        filename = strip_quotes(filename)
        size_opt = strip_quotes(size_opt)
        color_opt = strip_quotes(color_opt)

        if filename && !filename.empty?
          # 同じ画像・同じ設定ならスキップ
          key = "#{filename}-#{size_opt}-#{color_opt}"
          next if processed.include?(key)

          optimize_single(filename, size_opt, color_opt, force)
          processed.add(key)
        end
      end
    end

    private

    def strip_quotes(str)
      return nil unless str
      str.strip.gsub(/^[`'"]+|['"`]+$/, '')
    end

    def optimize_single(filename, size_opt, color_opt, force)
      src_files = Dir[@fat_dir.join("#{filename}*")]
      if src_files.empty?
        puts "    [Skip] #{filename}: 元画像(fatimage)が見つかりません"
        return
      end
      src_file = src_files.first
      src_ext = File.extname(src_file)

      # 拡張子の決定
      dest_ext = case color_opt
                 when 'P' then '.jpg'
                 when 'U', 'G', 'M' then '.png'
                 else src_ext
                 end
      
      basename = File.basename(filename, ".*")
      out_file = @out_dir.join(basename + dest_ext)

      if File.exist?(out_file) && !force
        return
      end

      # 元画像情報の取得 (magick identify)
      src_info = get_image_info(src_file)
      unless src_info
        puts "    [Error] #{filename}: 画像情報の取得に失敗しました (magick identify)"
        return
      end

      # サイズオプションの解決
      size_label = size_opt || "Default"
      resize_arg = case size_opt
                   when 'L' then '800x800>'
                   when 'S' then '350x350>'
                   when 'I' then '150x100!'
                   when /^\d+$/ then "#{size_opt}x#{size_opt}>"
                   else '600x600>' # Default M
                   end
      
      # 一時ファイル作成
      tmp_file = @out_dir.join("tmp_#{basename}#{dest_ext}")

      # 1. リサイズ実行 (magick)
      # magick src -resize ... dest
      unless system("magick", src_file.to_s, "-resize", resize_arg, tmp_file.to_s)
        puts "    [Error] magick(resize)に失敗しました: #{src_file}"
        return
      end

      # 2. 圧縮・最適化実行
      color_label = color_opt || "Default"

      case dest_ext.downcase
      when '.png'
        # --- pngquant (減色) ---
        # U=16, I=8, M=32, 数値指定, その他(Default)=32, O=スキップ
        quant_colors = case color_opt
                       when 'U' then 16
                       when 'I' then 8
                       when /^\d+$/ then color_opt.to_i
                       when 'O' then nil # Original (no quant)
                       else 32 # Default (M or empty)
                       end

        if quant_colors
          # --force: 上書き, --ext: 拡張子維持, --speed 1: 最高品質
          # エラーが出ても無視して進む(exception: false)
          system("pngquant", "--force", "--ext", ".png", "--speed", "1", quant_colors.to_s, tmp_file.to_s, exception: false)
        end

        # --- zopflipng (圧縮) ---
        # 処理時間がかかるため、tmpファイル間で処理
        # 失敗したりコマンドがない場合は無視して進む
        tmp_opt_file = @out_dir.join("opt_#{basename}.png")
        if system("zopflipng", "-y", "--lossy_transparent", "--lossy_8bit", "--iterations=10", "--filters=0me", tmp_file.to_s, tmp_opt_file.to_s, exception: false)
          FileUtils.mv(tmp_opt_file, tmp_file)
        end
        
      when '.jpg', '.jpeg'
        # --- jpegoptim ---
        # メタデータ削除(-s), 品質85
        system("jpegoptim", "--strip-all", "-m85", tmp_file.to_s, exception: false)
      end

      # 完成ファイルを配置
      FileUtils.mv(tmp_file, out_file)

      # 結果情報の取得
      dest_info = get_image_info(out_file)

      # ログ出力
      print_log(basename, src_ext, dest_ext, src_info, dest_info, size_label, resize_arg, color_label)
    end

    # 画像情報を取得: { w: int, h: int, size: int }
    def get_image_info(path)
      # magick identify -format "%w %h %B" (幅 高さ バイト数)
      out, status = Open3.capture2("magick", "identify", "-format", "%w %h %B", path.to_s)
      return nil unless status.success?
      w, h, b = out.split
      { w: w.to_i, h: h.to_i, size: b.to_i }
    rescue
      nil
    end

    # ログ出力
    def print_log(name, src_ext, dest_ext, src, dest, size_lbl, resize_arg, color_lbl)
      # 拡張子変化
      ext_str = (src_ext == dest_ext) ? src_ext : "#{src_ext}->#{dest_ext}"
      
      # 寸法変化
      dim_str = "#{src[:w]}x#{src[:h]}->#{dest[:w]}x#{dest[:h]}"
      
      # サイズ変化と削減率
      diff = dest[:size] - src[:size]
      percent = src[:size] > 0 ? (diff.to_f / src[:size] * 100).round : 0
      sign = percent > 0 ? "+" : "" # 通常はマイナスになるはず
      size_str = "#{human_size(src[:size])}->#{human_size(dest[:size])}"
      
      # 1行で整形出力
      # 例: [Proc] image (.png) | Dim:1920x1080->800x600(L) | Col:Default | Size:2.5MB->150KB(-94%)
      puts "    [Proc] #{name} (#{ext_str}) | Dim:#{dim_str}(#{size_lbl}) | Col:#{color_lbl} | Size:#{size_str}(#{sign}#{percent}%)"
    end

    def human_size(bytes)
      return "0B" if bytes == 0
      units = %w[B KB MB GB]
      e = (Math.log(bytes) / Math.log(1024)).floor
      s = "%.1f" % (bytes.to_f / 1024**e)
      s.sub(/\.0$/, '') + units[e]
    end
  end
end
