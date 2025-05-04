divert(-1)
# HT開始のおまじないを展開するとともに、スクリプトにメタデータを伝える。
# 1:タイトル 2:カテゴリ 3:タグ（,区切り）
define(_begin,`<!DOCTYPE html><html lang="ja"><head><title>$1</title> <meta charset="UTF-8"> <link rel="stylesheet" href="../css/article.css"></head><body>')
# HT終了のおまじない。最後に勝手に呼ばれるのでこちらから呼ぶ必要はない。
define(_end,`</body></html>')
# 見出し。
# 1:規模 2:内容
define(_h,`<h$1>$2</h$1>')
# コードブロック開始。前処理でエスケープしつつくっつけられてしまうので、書く時は
#  括弧を閉じた直後からコードを始めずに改行すること
# 1:<ファイル名などタイトル> 2:<コードの種類名。省略するとotherになる。詳細はcssで>
define(_code,`<div class="codebox">$1<pre class="ifelse($#,2,$2,`other')code"><code>changequote(`[[[[[',`]]]]]')')
# コードブロック終了。開始と同様に、ちゃんと改行すること。
define(_codeE,`</code></pre></div>changequote(`,')')
# 画像。ケチケチスクリプトはこのマクロを読んでケチるべき画像を判断している。
#  インライン要素扱いなので段落をくっつけたくなければ空行を噛ませること。
# 1:画像ファイル名 2:<alt文。"で閉じて別の属性を書くこともできる> 3:サイズパラメータ 4:色パラメータ
define(_img,`<img src="article/_artnum/syscmd(find image/ -name "$1*" | tr -d "\n")" alt="$2">')
define(_tips,`<div class="tips">')
define(_tipsE,`</div>')
define(_tsuiki,`<div class="tsuiki">')
define(_tsuikiE,`</div>')
# ●ポチ、数字による箇条書きは以下で囲む。その内部は一行一行がli要素となる。
define(_123,`<ol>')
define(_123E,`</ol>')
define(_kajo,`<ul>')
define(_kajoE,`</ul>')
# タイプが20%程度楽になるとの調査結果。
define(_br,`<br>')
# 前処理されたくない行の行頭に
define(_null,`')
define(_a,`<a href="$2" target="_blank" rel="noreferrer">$1</a>')
define(_ain,`<a href="$2">$1</a>')
define(_inyo,`<blockquote>')
define(_inyoE,`</blockquote>')
m4wrap(`_end')
divert(0)dnl

