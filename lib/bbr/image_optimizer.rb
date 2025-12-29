require 'fileutils'

module Bbr
  class ImageOptimizer
    def initialize(article_dir)
      @fat_dir = article_dir.join('fatimage')
      @out_dir = article_dir.join('image')
      FileUtils.mkdir_p(@out_dir)
    end

    # m4ソースから _img マクロを抽出して最適化を実行
    # force: 既存があっても再生成するか
    def run(src_path, force = false)
      puts "  [IMG] 画像最適化を開始します..."
      
      # _img(ファイル名, alt, サイズ, 色)
      # 正規表現で簡易抽出 (厳密にはm4パーサが必要だが、フォーマットが決まっているのでこれで)
      content = File.read(src_path)
      # _img(`hoge.png', ...) or _img(hoge.png, ...)
      content.scan(/_img\(['"]?([^'",]+)['"]?,\s*['"]?.*?['"]?,\s*['"]?([^'",]*)['"]?,\s*['"]?([^'",]*)['"]?\)/) do |filename, size_opt, color_opt|
        optimize_single(filename, size_opt, color_opt, force)
      end
    end

    private

    def optimize_single(filename, size_opt, color_opt, force)
      # fatimageから元画像を探す
      src_files = Dir[@fat_dir.join("#{filename}*")]
      if src_files.empty?
        puts "    [Skip] 元画像が見つかりません: #{filename}"
        return
      end
      src_file = src_files.first
      ext = File.extname(src_file)
      out_file = @out_dir.join(filename + ext) # 単純化のため同じ拡張子と仮定

      if File.exist?(out_file) && !force
        # puts "    [Skip] 処理済み: #{filename}"
        return
      end

      # サイズオプション解析
      resize_arg = case size_opt
                   when 'L' then '800x800>'
                   when 'S' then '350x350>'
                   when 'I' then '150x100!' # Icon
                   when /^\d+$/ then "#{size_opt}x#{size_opt}>" # 数字指定
                   else '600x600>' # Default M
                   end

      puts "    [Proc] #{filename} -> #{resize_arg}"
      
      # ImageMagick実行
      # 本来は pngquant / zopfli も呼ぶべきだが、まずは convert のみ実装
      cmd = "convert \"#{src_file}\" -resize \"#{resize_arg}\" \"#{out_file}\""
      system(cmd)
    end
  end
end
