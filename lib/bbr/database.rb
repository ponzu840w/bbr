require 'json'

module Bbr
  class Database
    def initialize(json_path)
      @path = json_path
      @data = File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    end

    # 記事データを更新する
    # options: { force: bool, update: bool, release: bool }
    def update_record(id, metadata, options)
      current_time = Time.now.to_i
      existing = @data[id]

      # タイムスタンプの決定ロジック
      timestamp = if existing
                    # 既存データがある場合
                    if options[:force]
                      puts "  [DB] -f 指定: タイムスタンプを強制更新します。"
                      current_time
                    elsif options[:update]
                      puts "  [DB] -u 指定: 既存のタイムスタンプ(#{existing['TIME']})を維持します。"
                      existing['TIME']
                    else
                      # 保護機能: 上書き指定がないのに既存データがある場合はエラー
                      raise "Error: 記事 #{id} のデータが既に存在します。\n" \
                            "  -f (強制上書き) または -u (内容のみ更新) を指定してください。"
                    end
                  else
                    # 新規データ
                    current_time
                  end

      # テストビルドかどうかのマーク (本番以外はIDの後ろにスペースを入れるハックの再現)
      # ※注: 元のスクリプトはJSONのキー(ID)の後にスペースを入れていましたが、
      # RubyのHashでそれをやると扱いづらいので、今回は「データとしては正しく保存する」方針にします。
      # ただし「テストビルドならDBを更新しない」という選択肢もありますが、
      # 元のスクリプトは "テストマーク付きで保存" していたため、
      # ここではシンプルに「常に保存する」ことにします。
      
      record = {
        "TITLE" => metadata[:title],
        "TIME" => timestamp,
        "CAT" => metadata[:category],
        "TAG" => metadata[:tags]
      }

      @data[id] = record
      save
      puts "  [DB] データベースを更新しました。"
      
      return timestamp # 決定したタイムスタンプを返す
    end

    private

    def save
      File.write(@path, JSON.pretty_generate(@data))
    end
  end
end
