#!/bin/sh -eu
# マクロで書かれたブログ記事を公開可能な形にビルドするシェルスクリプト
# posixを意識しつつwslが前提だったりする
# 大きく分けて、JSONデータベースの更新、画像データサイズの最適化（ケチる）、m4によるハイパーテキストの展開を行う
#set -vx  # デバッグ用

# 終了時はexitではなくbye関数を呼ぶこと。
# シンボリックリンクとして作成したtmpファイルのunlinkをどのタイミングでも必要とする。
bye () {
  for i in "${kechimbo_script}" "${macroDefineFile}" "${jsonFile}" "${esc_srcFile}" ; do
    unlink "${i}"
  done
  set +vx
  exit
}

echo "#####################
##Begin MakeArticle##
#####################"

# 引数オプションの保持。true=1,false=0
# opt_test=$(echo "$@" | awk 'BEGIN{RS=FS;t=0}/^-/{for(i=2;i<=length($0);i++){if(substr($0,i,1)=="t")t=1}}END{print t}')
opt_release=$(echo "$@" | awk 'BEGIN{RS=FS;r=0}/^-/{for(i=2;i<=length($0);i++){if(substr($0,i,1)=="r")r=1}}END{print r}')
opt_image=$(echo "$@" | awk 'BEGIN{RS=FS;i=0}/^-/{for(j=2;j<=length($0);j++){if(substr($0,j,1)=="i")i=1}}END{print i}')     # i-fatimageを参照してケチンボ省略
opt_skipimage=$(echo "$@" | awk 'BEGIN{RS=FS;i=0}/^-/{for(j=2;j<=length($0);j++){if(substr($0,j,1)=="I")i=1}}END{print i}') # I-既成ケチンボを参照して省略
opt_force=$(echo "$@" | awk 'BEGIN{RS=FS;f=0}/^-/{for(i=2;i<=length($0);i++){if(substr($0,i,1)=="f")f=1}}END{print f}')
opt_update=$(echo "$@" | awk 'BEGIN{RS=FS;u=0}/^-/{for(i=2;i<=length($0);i++){if(substr($0,i,1)=="u")u=1}}END{print u}')
opt_prev=$(echo "$@" | awk 'BEGIN{RS=FS;p=0}/^-/{for(i=2;i<=length($0);i++){if(substr($0,i,1)=="p")p=1}}END{print p}')
# 記事番号
artnum=$(echo "$@" | awk 'BEGIN{RS=FS;artnum=-1}/^[0-9]+/{artnum=sprintf("%05d",$0)}END{print artnum}')

if [ ${opt_force} -eq 1 -a ${opt_update} -eq 1 ];then
  echo "[警告]強制上書き（-f）と更新（-u）は共存できないオプションです。意味不明。切るよ。"
  echo "ｶﾞﾁｬﾝ"
  bye
fi

# Windows側のディレクトリを扱うため、スペースを含む厄介なフォルダ名を考慮する必要があり、扱う記事のファイルに関しては番号フォルダにcdし、
# 当スクリプトも置かれるblog/ファルダのファイルに関してはひとつひとつについてシンボリックリンクを/tmp/以下に作成してそれにアクセスすることで厄介を避ける。
# evalを駆使することでlnコマンドを成功させているが、これを作業中にいちいち書いてはいられない。

# スクリプトが置かれているディレクトリを得る
if command -v wslpath >/dev/null 2>&1; then
  # WSL 環境なら wslpath で Windows 形式→UNIX 形式に変換
  scriptdir=$(wslpath -u -a "$(dirname "$0")")
else
  # それ以外の環境では dirname＋cd＋pwd で絶対パスを取得
  scriptdir=$(cd "$(dirname "$0")" && pwd -P)
fi
scriptdir=${scriptdir%/}

echo "このスクリプトの場所: ${scriptdir}"

cd "./data" || { echo "Error: ./data にアクセスできない。" >&2; exit 1; }
datadir=${scriptdir}'/data'
echo "データの場所: ${datadir}"

# 番号記憶ファイル
currnumFile=$(mktemp)
currnumFile_fullpath=$(echo ${datadir}'/currentnum' | awk '{print("\""$0"\"")}')
eval ln -s -f $(echo ${currnumFile_fullpath}) ${currnumFile}

# 引数で番号が与えられていれば記憶ファイルを更新し、そうでなければ記憶を引き出す。
if [ $artnum -eq -1 ];then artnum=$(cat ${currnumFile})
else echo ${artnum} > ${currnumFile};fi
unlink ${currnumFile}

echo "ビルドする記事番号="${artnum}

# 画像サイズをケチるスクリプトファイル。長くなりすぎるから分割しただけでそこまでの汎用性はない。
kechimbo_script=$(mktemp)
kechimbo_script_fullpath=$(echo ${scriptdir}'/kechimbo.sh' | awk '{print("\""$0"\"")}')
eval ln -s -f $(echo ${kechimbo_script_fullpath}) ${kechimbo_script}

# ブログマクロ定義ファイル。
macroDefineFile=$(mktemp)
macroDefineFile_fullpath=$(echo ${scriptdir}'/html_article_define.m4' | awk '{print("\""$0"\"")}')
eval ln -s -f $(echo ${macroDefineFile_fullpath}) ${macroDefineFile}

# JSONデータベース。
jsonFile=$(mktemp)
jsonFile_fullpath=$(echo ${datadir}'/database.json' | awk '{print("\""$0"\"")}')
eval ln -s -f $(echo ${jsonFile_fullpath}) ${jsonFile}

# 対象記事ディレクトリをカレントディレクトリにする。
subjdir=$(echo ${datadir}'/article/'${artnum} | awk '{if(!match($0,/\/$/))$0=$0"/";print("\""$0"\"")}')
eval cd $(echo ${subjdir})

# 記事に属するファイル・フォルダとして、マクロで書かれた記事、処理前のデカいかもしれない画像を収めたフォルダ、処理後画像のフォルダ（これは無ければ生成される）
srcFile="./${artnum}.m4"
imageOutDir="./image/"
fatImageDir="./fatimage/"
if [ ! -r ${srcFile} ];then echo "[警告]記事ソース「(${srcFile})」が見つかりません。";bye;fi
if [ ! -r ${imageOutDir} ];then mkdir ${imageOutDir};fi

###
# JSONファイルの更新
###

# 過去にビルドしたときのタイムスタンプ。存在しなければ-1。
old_maketime=$( cat ${jsonFile} | awk 'BEGIN{old_maketime=-1} $1~/^"'"${artnum}"'":/{
  match($0,/"TIME":[0-9]+/);old_maketime=substr($0,RSTART+7,RLENGTH-7)}
END{print old_maketime}')

# タイムスタンプについての慎重なレポート
if [ ${old_maketime} -ne -1 ];then
  echo ${artnum}"番記事の過去のビルド「"${old_maketime}"」が存在します。"
  if [ ${opt_force} -eq 1 ];then
    echo "  -f オプションが指定されているため、これを破棄して現在のタイムスタンプを捺します。"
  elif [ ${opt_update} -eq 1 ];then
    echo "  -u オプションが指定されているため、このタイムスタンプを保持して内容のみ更新します。"
  fi
else
  echo ${artnum}"番記事の過去のビルドは存在しないか、テストビルドです。"
fi

# 過去にビルドしたことがあり、かつ強制上書きも更新もオプション指定されていなかった場合、警告を表示して終了。
if [ ${old_maketime} -ne -1 ] && [ ${opt_force} -eq 0  -a ${opt_update} -eq 0 ];then
  echo "[警告]既に"${artnum}"番記事のテストではないビルド「"${old_maketime}"」が存在します。タイムスタンプを守るために終了します。"
  echo "  -f オプションで強制的にタイムスタンプを含めて上書きすることができます。"
  echo "  -u オプションで古いタイムスタンプのみを保持してビルドできます。（追記更新等の場合用）"
  bye
fi

# 以前のタイムスタンプを引き継ぐか、現在のを捺すか。
if [ ${old_maketime} -ne -1 ] && [ ${opt_update} -eq 1 ];then
  maketime=${old_maketime}
else
  maketime=$(date +%s)  # このようにしてUNIX時間を得るのはPOSIX標準ではないらしい。かなしい。
  echo "現在のUNIX時間:"${maketime}
fi

# m4を使った処理を始める前に、codeブロック内をエスケープする前処理をしておく。
esc_srcFile=$(mktemp)
code_escaper='define(_code,`changequote(`[[[[['\'',`]]]]]'\'')'\'')\ndefine(_codeE,`changequote(`,'\'')'\'')\n'
cat ${srcFile} | awk 'BEGIN{area="outerspace"} { # AWK一段目：コードブロック以外のインデントを吹っ飛ばす（邪魔なので
match($0,/^[ \t]*/)
noid=substr($0,RLENGTH+1)
if(area=="outerspace"){
  print noid
}else{
  gsub(/&/,"\\&amp;");gsub(/</,"\\&lt;");gsub(/>/,"\\&gt;")
  print
}
if(noid~/^_code/){
  if(noid~/^_codeE/){
    area="outerspace"
  }else{
    area="code"
  }
}
}' |
awk 'BEGIN{area="outerspace"} { # AWK三段目：コードブロック用マクロ前後に専用クオートの挿入。
if($0~/^_code/){
  if($0~/^_codeE/){
    area="outerspace"
    printf("]]]]]\n%s",$0)
  }else{
    area="codetop"
    printf("\n%s",$0)
  }
}else{
  if(area=="codetop"){
    area="code"
    printf("\n[[[[[%s",$0)
  }else{
    printf("\n%s",$0)
  }
}
}' >${esc_srcFile}


# レコードを作成
# _beginというマクロにのみ注目する定義を付着させることで、_beginの引数として設定されたタイトル、カテゴリ、タグの集合を取得することができる。
# 過去のタイムスタンプを引き継がないテストビルド（過去がないか、-tf）の場合はJSON的には意味をなさないスペースを挿入し、勝手に上書きしてよいことを示す。
record=$(echo 'define(_begin,`divert(0)$1"$2"$3
divert(-1)'"')divert(-1)${code_escaper}" | cat - ${esc_srcFile} | m4 | awk 'BEGIN{FS="\""} {
split($3,arrtags,",")
for(tag in arrtags){
  if(tags)tags=tags","
  tags=tags"\""arrtags[tag]"\""
}
printf("\"%s\"%s:{\"TITLE\":\"%s\",\"TIME\":%s,\"CAT\":\"%s\",\"TAG\":[%s]},",artnum,testmark,$1,maketime,$2,tags)}' artnum="${artnum}" maketime="${maketime}" testmark="$(if [ ${opt_release} -eq 0 -a ${opt_update} -eq 0 ];then echo " ";else echo "";fi)") # "はJSで使うので、FSに最適（たぶん

echo "以下のレコードを追加します。"
echo ${record}

# 作成したレコードを挿入する。
tf=$(mktemp); cat ${jsonFile} | awk '$1!~/^"'"${artnum}"'"/{print}NR==1{print record}' record="${record}" >${tf}; cat ${tf}>${jsonFile};rm ${tf}

###
# 画像サイズをケチる
###

# テストでなければ、_imgマクロごとに適切な引数をkechimbo.shに与える。
#if [ ${opt_image} -eq 0 ];then
if [ ${opt_image} -eq 0 ] && [ ${opt_skipimage} -eq 0 ];then
  echo 'define(_img,`divert(0)$1 $3 $4
divert(-1)'"')divert(-1)${code_escaper}" | cat - ${esc_srcFile} | m4 |
  awk '{print(fid$1" "iod" "$2" "$3)}' fid="${fatImageDir}" iod="${imageOutDir}" |
  while read line; do
    (${kechimbo_script} ${line})
  done
  articon=$(find fatimage/ -name "articon*" | tr -d "\n")
  (${kechimbo_script} ${articon} ${imageOutDir} "I" "I")
else
  echo "-i/-Iオプションの為、画像処理をスキップしました。"
fi

# テストビルドの場合、ハイパーテキストでの画像フォルダをfatimage/に変更しておく
if [ ${opt_image} -eq 1 ];then
  fatsed="s:image/:fatimage/:"
else
  fatsed=""
fi

###
# ハイパーテキスト取得
###

echo "ハイパーテキスト展開開始"

# m4コマンドによって展開する前に、マクロなしで暗黙に包まれてほしい<p>要素および<li>要素をawkで包んであげる。
# ブロック要素と見做されるマクロ無しで連続した行はひとつの改行無し<p>要素とみなされ、<ol>、<ul>中では一行が一つの<li>要素となる。
# 空行があると別の段落となり、またリストが空行を持つことは想定していない。
echo "define(_artnum,${artnum})dnl" | cat - ${esc_srcFile} | #sed 's/^[ \t]*//' |
awk 'BEGIN{area="outerspace"; nest=0; p_child="_(a|img|br)" # 暗示されたpタグ・liタグの展開
while(1){getline;print;if($0~/^_begin/)break} # _beginまで読み飛ばしておく
} {
if($0!~/^[ \t]*$/){ # 空行でない
  if($0!~/^_/||$0~p_child){ # ストレートな、段落・リストに包まれる行
    if(area == "list"){
      print "<li>"$0
    }else if(area != "p" && area != "code"){
      area="p"
      print "<p>"
      print
    }else{
      print
    }
  }else{  # ブロック要素など、段落に含めるのが不適当な行
    if(area == "p"){# さっきまで段落が続いていたのなら、その終焉が訪れた
      area="outerspace"
      print "</p>"
    }
    if(area != "code"){
      if($0~/^_(123|kajo)([^E]|$)/){ # リスト開始
        area="list"
        nest=nest+1
      }else if($0~/^_code([^E]|$)/){ # コード開始
        area="code"
      }
    }
    print # 本文挿入。開始タグを入れるならこれより上、閉じタグはこれより下ということ。
    if($0~/^_(123|kajo)E/ && area != "code"){ # リスト終了
      nest=nest-1
      if(nest<=0)
        area="outerspace"
    }else if(area == "code" && $0~/^_codeE/){ # コード終了
      area="outerspace"
    }
  }
}else{ # 空行は、段落に現れれば段落の終わりを意味し、そうでなければ無視される。
        # 変更:コードブロック中の空行は省略しない
  if(area == "p"){
    area="outerspace"
    print "</p>"
  }else if(area == "code"){
    print
  }
}
} END{if(area=="p")print "</p>"}' |
awk 'BEGIN{area="outerspace"} { # コードブロック用マクロ前後の改行の削除。逆に初めから改行されていないと正しく処理されません今のところ
if($0~/^_code/){
  if($0~/^_codeE/){
    area="outerspace"
    printf("%s",$0)
  }else{
    area="codetop"
    printf("\n%s",$0)
  }
}else{
  if(area=="codetop"){
    area="code"
    printf("%s",$0)
  }else{
    printf("\n%s",$0)
  }
}
}' |
cat ${macroDefineFile} - | sed -e "${fatsed}" | m4 > ./html.html

echo "ハイパーテキスト展開完了"

if [ ${opt_prev} -eq 1 ];then
  echo "プレビューのためのpython httpサーバーを起動します。"

  if command -v wslpath >/dev/null 2>$1; then
    eval cd $(echo $(dirname $0)'/../../../')
    pwsh.exe -Command python3.exe -m http.server 8000 &
    echo "サーバーPID:"$!
    pwsh.exe -C start "http://localhost:8000/blog/blog.html?id="${artnum}
  else
    # それ以外の環境：普通の python3
    #preview_root=$(cd "$(dirname "$0")/../../../" && pwd -P)
    preview_root=$(cd "$(readlink ${datadir})/../" && pwd -P)
    eval cd "${preview_root}"
    echo "preview_root: ${preview_root}"
    # **ポート解放処理**
    if lsof -i TCP:8000 -sTCP:LISTEN >/dev/null 2>&1; then
      echo "ポート8000を使っている前回のサーバーを終了します…"
      kill -9 $(lsof -t -i TCP:8000)
      sleep 1
    fi
    python3 -m http.server 8000 &
    preview_pid=$!
    echo "サーバーPID:${preview_pid}"
    # Linux/macOS でブラウザを開く
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "http://localhost:8000/blog/blog.html?id=${artnum}" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
      open "http://localhost:8000/blog/blog.html?id=${artnum}" >/dev/null 2>&1 &
    else
      echo "ブラウザを自動起動できません。以下の URL を手動で開いてください:"
      echo "  http://localhost:8000/blog/blog.html?id=${artnum}"
    fi
  fi
fi

echo "ビルド完了"
bye
