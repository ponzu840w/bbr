#!/bin/bash

# 記事をアップロードする。更新とかはとりあえず考えない。
# 引数に記事番号（五桁でなくてよい）を渡すとそれをアップロードする。引数がおかしかったり無かったりすると、
# 最後にビルドした記事がアップロードされる。
# 念のためメタデータベースはバックアップを取る。
cd $(dirname $0)
server="ponzu840w.jp"
user="web@ponzu840w.jp"
artnum=$(echo "$@" | awk 'BEGIN{RS=FS;artnum=-1}/^[0-9]+/{artnum=sprintf("%05d",$0)}END{print artnum}')

# 番号記憶ファイル
# 引数で番号が与えられていればそれでよし、そうでなければ記憶を引き出す。
if [ $artnum -eq -1 ];then artnum=$(cat "./currentnum"); fi
echo "アップロードする記事番号="${artnum}

read -sp "FTP-Pass: " pass

ftp -n <<END
  open $server
  user $user $pass
  binary
  prompt
  cd blog/
  lcd tmp/
  get database.json
  lcd ../
  put database.json
  cd article/
  mkdir ${artnum}/
  cd ${artnum}/
  lcd article/
  lcd ${artnum}/
  put html.html
  mkdir image/
  cd image/
  lcd image/
  mput ./*
  ls
END

mv "./tmp/database.json" "./tmp/database_$(date +%s).json"
echo "アップロード完了"

