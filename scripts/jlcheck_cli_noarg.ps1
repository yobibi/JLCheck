#
# jlcheck_cli.ps1を実行
# 引数をここで記載することで.bat経由による変化可能性を防ぐ
#
# $logname : Amatsukaze管理ログ名（パス含まず）と比較。正規表現でマッチするか
# $tspath : 入力TSファイル名前部分（パス含まず）と比較。正規表現でマッチするか
# $service_id : サービスIDと比較。正規表現ない文字列記載なら完全一致で判断
# 

$logname = "^2026-0[4-6]"
$tspath = "大きい女の子"
$service_id = "211"

& ./jlcheck_cli.ps1 -logname $logname -tspath $tspath -s $service_id
