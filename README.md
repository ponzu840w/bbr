# bbr - Blog Body Retriever
高校生（当時）が文化祭準備期間にNEW GAME!を観ながらでっち上げたCGI不使用ブログシステム

[開発史兼運用サンプル](https://ponzu840w.jp/blog/blog.html?id=00000)

# 使い方
## 環境構築
```
ln -s /mnt/c/Users/ポン酢/OneDrive/ponzu840w.jp/blog/ data

sudo apt install imagemagick
sudo apt install pngquant
sudo apt install zopfli
sudo apt install ftp
```

## 新規記事作成
```
./set.sh -n                 # 新規記事をセット
vim ~/blogart/000XX.m4      # 記事を編集
cp ~/wh/Desktop/erogazou.png ~/blogart/fatimage/
                            # 記事に使う写真を格納
./build_article.sh -r       # リリースモードでビルド
./upload_article.sh         # アップロード
```

## 記事ビルドスクリプトの使い方

./build_article.sh 20
  数字列であることで判断されるオプション。作業番号が設定される（5桁である必要なし）。

./build_article.sh
  作業番号は控えられているので以降これだけでok

./build_article.sh -t
  fatimageが指定されて圧縮が行われず、jsonにテスト用であることを示すスペースが入るテスト出力。

./build_article.sh -f
  htmlと圧縮画像は従なのでいつ何時も上書きされるが、
  jsonはタイムスタンプを持つため安易に書き換えられない。
  -fオプションでタイムスタンプを含めて上書きする。
  既にjsonにテスト出力でない項目があって-fオプションも無ければエラー吐いて終了する。

./build_article.sh -u
  update。タイムスタンプを温存して他を上書きする。
  テスト用レコードでもタイムスタンプは拾わなければならないのでは？

./build_article.sh -p
  プレビュー。

./build_article.sh -i
  画像処理をスキップし、fatimageをそのまま使う。

./build_article.sh -I
  画像処理をスキップし、imageをそのまま使う。

# マジで覚えていないメモ類

## 記事リストjsonを和暦からunix時間に置換した時のコマンド
awk '$0!~/"G":"平成"/{print}/"G":"平成"/{match($0,/"Y":[0-9]+/);y=substr($0,RSTART+4,RLENGTH-4);match($0,/"M":[0-9]+/);m=substr($0,RSTART+4,RLENGTH-4);match($0,/"D":[0-9]+/);d=substr($0,RSTART+4,RLENGTH-4);printf("%s,\"TIME\":",substr($0,0,length($0)-3));"./utconv "sprintf("%d%02d%02d",y+1988,m,d)"" | getline ut;printf("%d},\n",ut)}' < art.json > article.json

json含め、ファイル名をまともなのに変更しようと思うが、合わせてキャッシュ拒否の為のランダムネームを含めることを検討したい。
