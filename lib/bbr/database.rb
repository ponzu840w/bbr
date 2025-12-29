require 'json'
require 'fileutils'

module Bbr
  class Database
    def initialize(json_path)
      @path = json_path
      # ファイルが存在しない、または空の場合は初期化
      if !File.exist?(@path) || File.zero?(@path)
        File.write(@path, "{\n}\n")
      end
    end

    # 記事データを更新する
    def update_record(id, metadata, options)
      current_time = Time.now.to_i
      
      # ファイルを読み込む
      lines = File.readlines(@path)
      
      # 検索キー: "00123": (インデントやクオート考慮)
      # 行指向で検索するため、行のどこかに "ID": があるか探す
      search_regex = /^\s*"#{id}":/
      
      existing_line = lines.find { |line| line =~ search_regex }
      existing_timestamp = nil

      if existing_line
        # TIMEを抽出 (正規表現)
        if existing_line =~ /"TIME":\s*(\d+)/
          existing_timestamp = $1.to_i
        end
      end

      # タイムスタンプ決定ロジック
      timestamp = if existing_timestamp
                    if options[:force]
                      puts "  [DB] -f 指定: タイムスタンプを強制更新します。"
                      current_time
                    elsif options[:update]
                      puts "  [DB] -u 指定: 既存のタイムスタンプ(#{existing_timestamp})を維持します。"
                      existing_timestamp
                    else
                      # 保護機能
                      raise "Error: 記事 #{id} のデータが既に存在します。\n" \
                            "  -f (強制上書き) または -u (内容のみ更新) を指定してください。"
                    end
                  else
                    current_time
                  end

      # 新しいレコード行を作成
      # RubyのJSON生成を使って値部分を作る
      record_hash = {
        "TITLE" => metadata[:title],
        "TIME" => timestamp,
        "CAT" => metadata[:category],
        "TAG" => metadata[:tags]
      }
      
      # JSON断片文字列: "00123":{"TITLE":...},
      # 元の実装通り、末尾に必ずカンマをつける
      new_record_line = %Q("#{id}":#{JSON.generate(record_hash)},\n)

      # ファイル再構築ロジック (awkの挙動を再現)
      # 1. 1行目 (通常は `{`)
      # 2. 新しいレコード (1行目の直後に挿入)
      # 3. 既存の行 (ただし、対象IDの行は除外)
      
      header = lines.first # {
      rest = lines[1..-1] || [] # } 含む残り
      
      # 対象IDの行を除外
      filtered_rest = rest.reject { |line| line =~ search_regex }
      
      # 結合
      # 注意: header が nil (空ファイル) の場合のガード
      new_content = if header
                      [header, new_record_line] + filtered_rest
                    else
                      ["{\n", new_record_line, "}\n"]
                    end
      
      File.write(@path, new_content.join)
      
      puts "  [DB] データベースを更新しました。"
      return timestamp
    end

    # 指定IDのレコード情報を取得する
    def get_record(id)
      return nil unless File.exist?(@path)
      
      # 行指向検索
      lines = File.readlines(@path)
      search_regex = /^\s*"#{id}":/
      line = lines.find { |l| l =~ search_regex }
      
      return nil unless line

      # 簡易パース (正規表現で抜く)
      info = {}
      if line =~ /"TITLE":"(.*?)"/
        info[:title] = $1
      end
      if line =~ /"TIME":(\d+)/
        info[:time] = $1.to_i
      end
      info
    end

  end
end
