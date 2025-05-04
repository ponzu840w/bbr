#! /bin/sh

# 画像ファイルをひたすらケチる。サイズ縮小色数削減最適化の流れ
# 第一引数=元ファイル 第二引数=保存先ディレクトリ（最後の/必須） 第三引数=サイズオプション 第四引数=色オプション
# 必要パッケージ：imagemagick, pngquant, zopfli, jpegoptim
#set -vx
echo "
##Begin Kechimbo##

元画像ファイル:"$1"
保存先ディレクトリ:"$2"
サイズオプション:"$3"
色数オプション:"$4

largefile=$1
outdir=$2
sizeopt=$3    # O,L,>M,S,<num>,I
coloropt=$4   # O,P,>M,U,G,<num>,I

if [ ! -f ${largefile} ];then echo "[警告]元画像ファイルが読み込めません。";exit;fi
if [ ! -d ${outdir} ];then echo "[警告]保存先ディレクトリがアクセスできません。";exit;fi

orgHeight=$(identify -format '%h' ${largefile})
orgWidth=$(identify -format '%w' ${largefile})

outname=$(basename ${largefile%.*})
orgext="."${largefile##*.}

echo "画像名:"${outname}", :入力拡張子:"${orgext}

LARGE=800
MIDIUM=600
SMALL=350

echo "元画像サイズ:"${orgHeight}"x"${orgWidth}

# ImageMagick
case "${sizeopt}" in
  ("O") maxSize="";;
  ("L") maxSize=${LARGE} ;;
  ("S") maxSize=${SMALL} ;;
  #(+([0-9])) maxSize=${sizeopt} ;;
  #("M"|*) maxSize=${MIDIUM} ;;
  ("M"|*) if expr "${sizeopt}" : "[0-9]*$" > /dev/null ; then maxSize=${sizeopt}
          else maxSize=${MIDIUM}; fi;;
esac

size=""
if [ ${sizeopt} = "I" ];then
  size="150x100!"
  echo "ImageMagickでの縮小予定:アイコン専用サイズ"${size}
elif [ ${maxSize} ] && [ ${orgHeight} -gt ${maxSize} -o ${orgWidth} -gt ${maxSize} ]; then
  size=${maxSize}"x"${maxSize}
  echo "ImageMagickでの縮小予定:"${size}"ピクセル四方の範囲内に収まるよう縮小されます。"
fi

outext=""
case "${coloropt}" in
  ("O") outext=${orgext};;
  ("P") outext=".jpg" ;;
  ("U"|"G"|"M"|*) outext=".png" ;;
esac

tmpfile=$(mktemp --suffix=${outext})
echo "縮小後減色前一時ファイル作成:"${tmpfile}
if [ ${size} ]; then
  echo "縮小を実行…"
  convert -resize ${size} ${largefile} ${tmpfile}
elif [ ! ${orgext} = ${outext} ]; then
  echo "元画像が指定サイズより小さいため、拡張子変換のみ実行…"
  convert ${largefile} ${tmpfile}
else
  echo "元画像が指定サイズより小さいため、コピーのみ実行…"
  cp ${largefile} ${tmpfile}
fi

# 減色処理
#resizedImageType=$(file --mime ${outdir}${outname} | awk '{match($0,/image\/[a-z]+;/);print(substr($0,RSTART+6,RLENGTH-7))}')

#echo ${resizedImageType}

color=""
case "${coloropt}" in
  ("O") ;;
  ("P") ;;
  ("U") color=16 ;;
  ("I") color=8 ;;
  #(+([0-9])) color=${coloropt} ;;
  ("M"|*) if expr "${coloropt}" : "[0-9]*$" > /dev/null ; then color=${coloropt}
          else color=32; fi;;
esac

#echo "color="${color}
if [ ${color} ]; then
  echo "pngquantによる"${color}"色にまでの減色開始…"
  pngquant --verbose ${color} --ext ${outext} ${tmpfile} --force
fi

# non-less (or lossy)
oldext=""
if [ ! _${orgext} = _${outext} ] && [ ! _${sizeopt} = "_I" ] && [ ! _${coloropt} = "_I" ]; then oldext=${orgext}; fi
case "${outext}" in
  (".png") echo "zopflipngによる最終処理開始…";zopflipng -y --lossy_transparent --lossy_8bit --iterations=20 --filters=0me ${tmpfile} ${outdir}${outname}${oldext}".png" ;;
  (".jpg"|".jpeg") "jpegoptimによる最終処理開始…";jpegoptim --strip-all -o -d ${outdir} ${tmpfile};
    mv ${outdir}$(basename ${tmpfile}) ${outdir}${outname}${oldext}".jpg" ;;
  (*) cp ${tmpfile} ${outdir}${outname}${oldext}${outext} ;;
esac

rm ${tmpfile}

echo "#ケチり終わり#"

