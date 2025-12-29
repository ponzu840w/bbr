require 'fileutils'
require 'open3'
require 'set'

module Bbr
  class ImageOptimizer
    def initialize(article_dir, verbose: false)
      @fat_dir = article_dir.join('fatimage')
      @out_dir = article_dir.join('image')
      @verbose = verbose
      FileUtils.mkdir_p(@out_dir)
    end

    def run(src_path, force = false)
      puts "  [IMG] 画像最適化を開始します..."
      
      # 1. m4を使って画像リストを抽出
      extractor_macro = <<~M4
        define(_img,`divert(0)$1\t$3\t$4\ndivert(-1)')
        divert(-1)
      M4

      article_dir = File.dirname(src_path)
      raw_content = File.read(src_path)
      
      output, stderr, status = Open3.capture3("m4", stdin_data: extractor_macro + raw_content, chdir: article_dir)

      unless status.success?
        puts "  [IMG] 警告: 画像リスト抽出中にm4のエラーが発生しました: #{stderr}"
      end

      # 2. _img リストの処理
      processed = Set.new
      output.each_line do |line|
        line.strip!
        next if line.empty?
        
        filename, size_opt, color_opt = line.split("\t")
        filename = strip_quotes(filename)
        size_opt = strip_quotes(size_opt)
        color_opt = strip_quotes(color_opt)

        if filename && !filename.empty?
          key = "#{filename}-#{size_opt}-#{color_opt}"
          next if processed.include?(key)

          optimize_single(filename, size_opt, color_opt, force)
          processed.add(key)
        end
      end

      # 3. articon の特別処理
      # 元仕様: articon=$(find fatimage/ -name "articon*" ...) -> I I オプションで処理
      Dir[@fat_dir.join("articon*")].each do |articon_path|
        filename = File.basename(articon_path, ".*")
        # articonは常に I, I 設定
        optimize_single(filename, "I", "I", force)
      end
    end

    private

    def strip_quotes(str)
      return nil unless str
      str.strip.gsub(/^[`'"]+|['"`]+$/, '')
    end

    # コマンド実行ラッパー
    def run_command(*args)
      cmd_str = args.join(' ')
      
      if @verbose
        puts "    [Cmd] #{cmd_str}"
        # verboseなら標準出力をそのまま流す
        system(*args)
      else
        # verboseでないなら出力をキャプチャして捨てる（エラー時のみ表示）
        out, err, status = Open3.capture3(*args)
        unless status.success?
          puts "    [Error] Command failed: #{cmd_str}"
          puts err # エラー内容は必ず出す
        end
        status.success?
      end
    end

    def optimize_single(filename, size_opt, color_opt, force)
      src_files = Dir[@fat_dir.join("#{filename}*")]
      if src_files.empty?
        puts "    [Skip] #{filename}: 元画像(fatimage)が見つかりません" if @verbose
        return
      end
      src_file = src_files.first
      src_ext = File.extname(src_file)

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

      # magick identify
      src_info = get_image_info(src_file)
      unless src_info
        puts "    [Error] #{filename}: 画像情報の取得に失敗しました (magick identify)"
        return
      end

      # サイズオプション
      size_label = size_opt || "Default"
      resize_arg = case size_opt
                   when 'L' then '800x800>'
                   when 'S' then '350x350>'
                   when 'I' then '150x100!'
                   when /^\d+$/ then "#{size_opt}x#{size_opt}>"
                   else '600x600>' 
                   end
      
      tmp_file = @out_dir.join("tmp_#{basename}#{dest_ext}")

      # 1. リサイズ実行
      unless run_command("magick", src_file.to_s, "-resize", resize_arg, tmp_file.to_s)
        return
      end

      # 2. 圧縮・最適化
      color_label = color_opt || "Default"

      case dest_ext.downcase
      when '.png'
        # --- pngquant ---
        quant_colors = case color_opt
                       when 'U' then 16
                       when 'I' then 8
                       when /^\d+$/ then color_opt.to_i
                       when 'O' then nil 
                       else 32 
                       end

        if quant_colors
          # exception: false は system 用だが、run_command は true/false を返すので判定不要
          run_command("pngquant", "--force", "--ext", ".png", "--speed", "1", quant_colors.to_s, tmp_file.to_s)
        end

        # --- zopflipng ---
        tmp_opt_file = @out_dir.join("opt_#{basename}.png")
        if run_command("zopflipng", "-y", "--lossy_transparent", "--lossy_8bit", "--iterations=10", "--filters=0me", tmp_file.to_s, tmp_opt_file.to_s)
          FileUtils.mv(tmp_opt_file, tmp_file)
        end
        
      when '.jpg', '.jpeg'
        # --- jpegoptim ---
        run_command("jpegoptim", "--strip-all", "-m85", tmp_file.to_s)
      end

      FileUtils.mv(tmp_file, out_file)

      dest_info = get_image_info(out_file)
      print_log(basename, src_ext, dest_ext, src_info, dest_info, size_label, resize_arg, color_label)
    end

    def get_image_info(path)
      out, status = Open3.capture2("magick", "identify", "-format", "%w %h %B", path.to_s)
      return nil unless status.success?
      w, h, b = out.split
      { w: w.to_i, h: h.to_i, size: b.to_i }
    rescue
      nil
    end

    def print_log(name, src_ext, dest_ext, src, dest, size_lbl, resize_arg, color_lbl)
      ext_str = (src_ext == dest_ext) ? src_ext : "#{src_ext}->#{dest_ext}"
      dim_str = "#{src[:w]}x#{src[:h]}->#{dest[:w]}x#{dest[:h]}"
      
      diff = dest[:size] - src[:size]
      percent = src[:size] > 0 ? (diff.to_f / src[:size] * 100).round : 0
      sign = percent > 0 ? "+" : "" 
      size_str = "#{human_size(src[:size])}->#{human_size(dest[:size])}"
      
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
