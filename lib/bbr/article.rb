# ブログ記事のモデル
module Bbr
  class Article
    attr_reader :id, :context

    def initialize(id, context)
      @id = id
      @context = context
    end

    # 記事のルートディレクトリ (例: .../article/00123)
    def path
      @context.articles_dir.join(@id)
    end

    # ソースファイル (例: .../article/00123/00123.m4)
    def source_path
      path.join("#{@id}.m4")
    end

    # 生成されるHTML
    def html_path
      path.join("html.html")
    end

    # 画像ディレクトリ
    def image_dir
      path.join('image')
    end

    def fat_image_dir
      path.join('fatimage')
    end

    # 記事として有効か（ディレクトリとm4が存在するか）
    def exists?
      path.directory? && source_path.exist?
    end

    # エディタで開く際の対象パス（通常はm4だが、なければディレクトリ）
    def edit_target
      source_path.exist? ? source_path : path
    end
  end
end
