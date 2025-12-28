require 'fileutils'

module Bbr
  class Manager
    def initialize(root_dir)
      @root_dir = root_dir
      @article_dir = File.join(@root_dir, 'article')
      @current_num_file = File.join(@root_dir, 'currentnum')
    end

    # 現在選択中の記事番号を表示
    def show_current
      if File.exist?(@current_num_file)
        id = File.read(@current_num_file).strip
        puts "現在の作業記事: #{id}"
        puts "パス: #{File.join(@article_dir, id)}"
      else
        puts "現在選択されている記事はありません。"
      end
    end

    # 指定した番号をセットする (bbr set ID)
    def set_article(id)
      # 5桁ゼロ埋めに正規化
      formatted_id = sprintf("%05d", id.to_i)
      target_path = File.join(@article_dir, formatted_id)

      unless Dir.exist?(target_path)
        puts "エラー: 記事ディレクトリ #{formatted_id} が見つかりません。"
        exit 1
      end

      # currentnum を更新
      File.write(@current_num_file, formatted_id)

      # ルートディレクトリの 'art' シンボリックリンクを更新 (旧互換性のため)
      update_symlink(target_path)

      puts "記事 #{formatted_id} をセットしました。"
    end

    # 新規記事を作成してセットする (bbr new)
    def create_new
      new_id = next_article_id
      new_dir = File.join(@article_dir, new_id)

      puts "新規記事 #{new_id} を作成します..."

      # ディレクトリ作成
      FileUtils.mkdir_p([
        new_dir,
        File.join(new_dir, 'image'),
        File.join(new_dir, 'fatimage')
      ])

      # テンプレートm4作成
      m4_path = File.join(new_dir, "#{new_id}.m4")
      unless File.exist?(m4_path)
        File.write(m4_path, "include(../../html_article_define.m4)\n_begin(タイトル,,)\n\n本文\n\n_end")
      end

      # 作成した記事をセット
      set_article(new_id)
    end

    private

    # 0番以降で空いている最小のIDを探索して返す
    def next_article_id
      return "00000" unless Dir.exist?(@article_dir)

      # 1. 存在するIDを全て取得して整数化し、昇順にソートする
      existing_ids = Dir.children(@article_dir)
                        .select { |name| name.match?(/^\d+$/) }
                        .map(&:to_i)
                        .sort

      # 2. ソート済みのリストを頭から照合し、インデックスと一致しない場所（欠番）を探す
      existing_ids.each_with_index do |id, index|
        if id != index
          # 例: [0, 1, 3] の場合
          # index 0, id 0 (OK)
          # index 1, id 1 (OK)
          # index 2, id 3 (NG! ここで 2 が抜けているとわかる)
          return sprintf("%05d", index)
        end
      end

      # 3. 途中に欠番がなければ、末尾の次の番号（つまり現在の記事数と同じ値）を返す
      # 例: [0, 1, 2] (size=3) -> 次は 3
      sprintf("%05d", existing_ids.size)
    end

    # ルートにある 'art' リンクを更新
    def update_symlink(target_path)
      link_path = File.join(@root_dir, 'art')
      # 既存リンクがあれば削除
      FileUtils.rm(link_path) if File.symlink?(link_path) || File.exist?(link_path)
      # シンボリックリンク作成
      FileUtils.ln_s(target_path, link_path)
    end
  end
end
