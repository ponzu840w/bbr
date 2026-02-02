require_relative 'article'

# ブログ記事の集合のモデル
module Bbr
  class Repository
    def initialize(context)
      @context = context
    end

    # IDを指定してArticleオブジェクトを取得
    def find(id)
      formatted_id = sprintf("%05d", id.to_i)
      Bbr::Article.new(formatted_id, @context)
    end

    # 現在記事番号の記事を取得
    def current
      return nil unless @context.current_num_file.exist?

      id = @context.current_num_file.read.strip
      find(id)
    end

    # 現在記事番号を設定
    def set_current(article)
      unless article.exists?
        raise "記事 #{article.id} が存在しません。"
      end
      File.write(@context.current_num_file, article.id)
    end

    # 全記事を取得
    def all
      return [] unless @context.articles_dir.exist?

      @context.articles_dir.children
              .select { |path| path.directory? && path.basename.to_s.match?(/^\d+$/) }
              .map { |path| find(path.basename.to_s) }
              .sort_by { |article| article.id }
    end

    # 次の空きIDを算出
    def next_id
      return "00000" unless @context.articles_dir.exist?

      # 存在するID(数値)のリスト
      existing_ids = all.map { |a| a.id.to_i }

      # 欠番を探す
      existing_ids.each_with_index do |id, index|
        if id != index
          return sprintf("%05d", index)
        end
      end

      # 欠番がなければ末尾の次
      sprintf("%05d", existing_ids.size)
    end

  end
end
