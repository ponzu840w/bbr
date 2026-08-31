# bbr - Blog Body Retriever
高校生（当時）が文化祭準備期間にNEW GAME!を観ながらでっち上げたCGI不使用ブログシステム

[開発史兼運用サンプル](https://ponzu840w.jp/blog/blog.html?id=00000)

# 使い方
## 環境構築
```
# ブログデータの場所を環境変数で指定
export BBR_REPO=/path/to/blog/data        # 例: ~/.od/ponzu840w.jp/blog

# 必須コマンド
sudo apt install m4 imagemagick pngquant zopfli

# プレビューサーバー用 (bbr prev を使う場合のみ)
gem install webrick
```

## 新規記事作成
```
bbr new                       # 空き番号で記事ディレクトリ生成 + テンプレ.m4 配置 + currentnum 設定
bbr edit                      # $EDITOR で .m4 を開く
cp ~/Desktop/erogazou.png $(bbr pwd)/fatimage/
                              # 記事に使う元画像を fatimage/ に格納
bbr test                      # ビルド（既存記事は対話で f/u/Cancel を選択）
bbr deploy                    # FTPアップロード
```

## bbr コマンド一覧

| コマンド | 役割 |
|---|---|
| `bbr new` | 空き番号で新規記事を作成し作業対象にセット |
| `bbr set <ID>` | 既存記事を作業対象にセット (5桁ゼロ埋め不要) |
| `bbr status` | DB登録・ビルド・画像の各状態を表示 |
| `bbr edit` | `$EDITOR` で対象記事の .m4 を開く |
| `bbr dir` | 対象記事ディレクトリをファイラで開く |
| `bbr pwd` | 対象記事ディレクトリのパスを出力 |
| `bbr test [ID]` | ビルド (既存記事は対話で `[F]orce` / `[U]pdate` / `[C]ancel`) |
| `bbr clean` | image/ を削除（確認あり） |
| `bbr prev [ID]` | プレビューサーバーを起動しブラウザを開く |
| `bbr stop` | プレビューサーバーを停止 |
| `bbr deploy [ID]` | FTPで html.html / image / database.json をアップロード |

## bbr test オプション

```
bbr test                      # 対話モード（既存記事のみ）
bbr test -f                   # Force: 既存タイムスタンプを破棄して再ビルド + 画像全再生成
bbr test -u                   # Update: タイムスタンプ温存で再ビルド + 画像増分のみ
bbr test --fast               # 画像最適化をスキップし fatimage を直接参照
bbr test -v                   # 詳細ログ
bbr test 20                   # 数字列で対象IDを指定（5桁ゼロ埋め不要）
```

# マジで覚えていないメモ類

## 記事リストjsonを和暦からunix時間に置換した時のコマンド
awk '$0!~/"G":"平成"/{print}/"G":"平成"/{match($0,/"Y":[0-9]+/);y=substr($0,RSTART+4,RLENGTH-4);match($0,/"M":[0-9]+/);m=substr($0,RSTART+4,RLENGTH-4);match($0,/"D":[0-9]+/);d=substr($0,RSTART+4,RLENGTH-4);printf("%s,\"TIME\":",substr($0,0,length($0)-3));"./utconv "sprintf("%d%02d%02d",y+1988,m,d)"" | getline ut;printf("%d},\n",ut)}' < art.json > article.json

json含め、ファイル名をまともなのに変更しようと思うが、合わせてキャッシュ拒否の為のランダムネームを含めることを検討したい。
