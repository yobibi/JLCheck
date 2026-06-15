# JLCheck Boot Script
#
# 内容： CM解析(join_logo_scp)部分のみ実行して結果を出力する
#
# 構成： [indata]は入力依存データ、[common]以降は共通設定
#

#--- UTF8 ---
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
#--- エラー処理開始 ---
try{

# [indata]
# --- 番組情報（設定することでタイトル別動作を設定可能） ---
$env:TS_IN_PATH = 'xxxx.ts'

# --- 放送局情報（ID/ABBRのどちらかを設定で放送局別動作を設定可能） ---
$env:SERVICE_ID = "211"
# $env:SERVICE_ABBR = 'BS11'

#--- join_logo_scp起動設定（設定固定したい場合は[common]に記述） ---
$JLC_JLS = '../../../exe_files/join_logo_scp.exe'
$JLC_INCMD = '../../../JL/JL_ANYSEL.txt'
$JLC_OPTION = ''

#--- ロゴ使用有無（使用時は1、未使用時は0を設定） ---
$JLC_USE_LOGO = 1


# [common]
#--- Amatsukazeログから絶対パスに変更ある場合等はコメントを外して固定設定 ---
#$JLC_JLS = '../../../exe_files/join_logo_scp.exe'
#$JLC_INCMD = '../../../JL/JL_ANYSEL.txt'

#--- 表示文字コード ---
$JLC_OPTION = '-stdcode UTF8N ' + $JLC_OPTION

#--- 固定設定 ---
$JLC_INSCP  = 'chapter_exe0.txt'   # 無音シーンチェンジ入力
$JLC_INLOGO = 'logof0.txt'         # ロゴ区間入力
$JLC_INNAME = 'string_name.txt'    # 結果対象認識用文字列
$JLC_O_TRIM = 'trim0.avs'          # 出力(Trim-AVS)
$JLC_O_SCP  = 'jls0.txt'           # 出力(構成詳細)
$JLC_O_DIV  = 'div0.txt'           # 出力(分割位置)
$JLC_RESULT = 'jlcheck0.txt'       # 出力(結果を1ファイルに結合)


# [execution]
#--- カレントディレクトリをこのファイル場所に ---
$pathBakCurrentPwsh = Get-Location
$pathBakCurrentSys  = [IO.Directory]::GetCurrentDirectory()
Set-Location -LiteralPath "${PSScriptRoot}"
[IO.Directory]::SetCurrentDirectory("${PSScriptRoot}")

#--- チェック ---
if (-not [string]::IsNullOrWhiteSpace($env:TS_IN_PATH)) {
  if ($env:TS_IN_PATH.Contains('?')){
    Write-Host "warning: ? in TS_IN_PATH. It may have changed in the log output"
    Write-Host "--- Rewriting is recommended (解析起動スクリプト修正で置換を推奨)"
  }
}

#--- 引数設定 ---
$jlsArgs = @()
if ($JLC_USE_LOGO -ne 0){
  $jlsArgs += "-inlogo"
  $jlsArgs += $JLC_INLOGO
}
$jlsArgs += "-inscp"
$jlsArgs += $JLC_INSCP
$jlsArgs += "-incmd"
$jlsArgs += $JLC_INCMD
$jlsArgs += "-o"
$jlsArgs += $JLC_O_TRIM
$jlsArgs += "-oscp"
$jlsArgs += $JLC_O_SCP
$jlsArgs += "-odiv"
$jlsArgs += $JLC_O_DIV
if (-not [string]::IsNullOrWhiteSpace($JLC_OPTION)) {
  $jlsArgs += $JLC_OPTION.Trim() -split '\s+'
}

#--- 実行前にjoin_logo_scp出力ファイル削除 ---
if ([System.IO.File]::Exists($JLC_O_TRIM)){
  [System.IO.File]::Delete($JLC_O_TRIM)
}
if ([System.IO.File]::Exists($JLC_O_SCP)){
  [System.IO.File]::Delete($JLC_O_SCP)
}
if ([System.IO.File]::Exists($JLC_O_DIV)){
  [System.IO.File]::Delete($JLC_O_DIV)
}
if ([System.IO.File]::Exists($JLC_RESULT)){
  [System.IO.File]::Delete($JLC_RESULT)
}
#--- join_logo_scp実行 ---
& "${JLC_JLS}" $jlsArgs

#--- 出力はフルパスにする(PowerShell5制約)---
#（パス途中に[]等が存在するとパス記載なしでもSet-Content/Add-Contentが動作しない）
$JLC_RESULT_FULL = Join-Path ([IO.Directory]::GetCurrentDirectory()) $JLC_RESULT

#--- 結果を1ファイルにまとめ ---
if ([System.IO.File]::Exists($JLC_O_TRIM)){
  if ([System.IO.File]::Exists($JLC_INNAME)){
    Get-Content  $JLC_INNAME | Set-Content -LiteralPath $JLC_RESULT_FULL -Encoding UTF8
  }
  else{
    $header = '#(name) ' + [System.IO.Path]::GetFileName(${PSScriptRoot})
    Set-Content -LiteralPath $JLC_RESULT_FULL -Value $header -Encoding UTF8
  }
  Get-Content  $JLC_O_TRIM | Add-Content -LiteralPath $JLC_RESULT_FULL
  if ([System.IO.File]::Exists($JLC_O_DIV)){
    Get-Content  $JLC_O_DIV | Add-Content -LiteralPath $JLC_RESULT_FULL
  }
  if ([System.IO.File]::Exists($JLC_O_SCP)){
    Get-Content  $JLC_O_SCP | Add-Content -LiteralPath $JLC_RESULT_FULL
  }
  Write-Host "JLCheck output -- $JLC_RESULT"
}
else {
  Write-Host "failed join_logo_scp"
}

#--- カレントディレクトリを戻す ---
Set-Location -LiteralPath "${pathBakCurrentPwsh}"
[IO.Directory]::SetCurrentDirectory("${pathBakCurrentSys}")

#--- エラー処理終了 ---
}
catch{
  Write-Host "error in .ps1:"
  Write-Output $_
}
