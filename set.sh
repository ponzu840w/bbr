#! /bin/bash -eu

### 記事番号をセットする ###
# 引数なし : 現在の記事番号を取得してセット
# -n option: 新規記事テンプレートを作成してセット
# 引数あり : その番号をセット

#set -vx  # デバッグ用

# 引数オプションの保持。true=1,false=0
opt_new=$(echo "$@ hoge" | awk 'BEGIN{RS=FS;r=0}/^-/{for(i=2;i<=length($0);i++){if(substr($0,i,1)=="n")r=1}}END{print r}')

# wslでwindows側のひどいディレクトリを扱うために
if which clip.exe >/dev/null 2>&1; then
  scriptdir=$(wslpath -u -a $(dirname $0))
else
  scriptdir="$(cd $(dirname $0); pwd)/"
fi
eval cd $(echo ${scriptdir})
echo "このスクリプトの場所: $scriptdir"

cd "./data" || { echo "Error: ./data にアクセスできない。" >&2; exit 1; }

# 番号記憶ファイル
currnumFile=$(mktemp)
#currnumFile_fullpath=$(echo ${scriptdir}'/data/currentnum' | awk '{print("\""$0"\"")}')
currnumFile_fullpath=$(echo ${scriptdir}'/data/currentnum')
eval ln -sf $(echo ${currnumFile_fullpath}) ${currnumFile}
echo "番号記憶ファイル: $currnumFile_fullpath"
echo "  [$(cat $currnumFile_fullpath)]"
echo "番号記憶ファイル用一時リンク: $currnumFile"
echo "  [$(cat $currnumFile)]"

# 記事番号ロジック
if [ $opt_new -eq 1 ];then
# 新規記事番号を取得してセット。
  echo "-nオプション: 新規記事番号を取得してセットします。"
  artnum=$(ls article/ | awk 'BEGIN{i=0}{if(i!=$0)print i;i++}')
else
# 引数で番号が与えられていなければ、記憶を引き出してセット。
#   そうでなければ、引数の番号をセットして記憶。
  artnum=$(echo "$@" | awk 'BEGIN{RS=FS;artnum=-1}/^[0-9]+/{artnum=sprintf("%05d",$0)}END{print artnum}')
  if [ $artnum -eq -1 ];then
    echo "引数なし: 現在の記事番号を取得してセットします。"
    artnum=$(cat ${currnumFile})
  else
    echo "引数あり: 引数で指定された番号をセットします。"
  fi
fi

# %05dに正規化
artnum=$(echo ${artnum} | awk '{print $0+0}')
artnum=$(printf %05d $artnum)
echo "セット記事番号: ${artnum}"

echo ${artnum} > ${currnumFile}
unlink ${currnumFile}

# 新規記事テンプレート作成
if [ $opt_new -eq 1 ];then
  mkdir "article/${artnum}"\
        "article/${artnum}/image"\
        "article/${artnum}/fatimage"
  touch "article/${artnum}/${artnum}.m4"
  echo "新規記事テンプレートを作成しました。"
fi

# リンク作成
unlink ${scriptdir}'/art' || true
eval ln -sf "${scriptdir}data/article/${artnum}" "${scriptdir}/art"
