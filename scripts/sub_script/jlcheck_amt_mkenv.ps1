#
# [内容]
#   Amatsukazeログからjoin_logo_scp実行に必要な環境作成
# [コマンド]
#   jlcheck_amt_mkenv.ps1 [filename] -work [workdir]
#   jlcheck_amt_mkenv.ps1 [filename] -work [workdir] -ts [tspath]
# [引数]
#   [filename] : 読み込むAmatsukazeログのファイル名
#   [workdir]  : 出力先フォルダ名
#   [tspath]   : TS_IN_PATHに確定設定するTSパス名
# [返り値]
#   $LASTEXITCODE : 0=正常終了 1=実行なし
# [出力]
#   [workdir]/*  :出力ファイル(*部分)はファイル名情報を参照
#   [workdir]/tspath.txt  入力で-tsを指定した時出力する
# [使用スクリプト]
#   jlcheck_filelist.ps1  : ファイル名情報
#   amtlog2jls.ps1        : Amatsukazeログからjoin_logo_scp実行に必要な情報取得
#

#----------------------------------------------------------
# ファイル名設定
#----------------------------------------------------------
#--- 別ファイルから読み込み ---
[string] $subdir        = "${PSScriptRoot}"
[string] $pathFileList  = Join-Path $subdir "jlcheck_filelist.ps1"
. $pathFileList

#----------------------------------------------------------
# 実行
#----------------------------------------------------------
#--- 入力ファイル名取得 ---
if ($args.Length -lt 3 -or ($args[1] -ne '-work')){
  Write-Host 'Usage: jlcheck_amt_mkenv.ps1 [filename] -work [workdir]'
  exit 1
}
[string] $pathAmtLog = $args[0]
[string] $dirWorkFull = $args[2]
[string] $pathTs = ""
if ($args.Length -gt 4 -and ($args[3] -eq '-ts')){
  $pathTs = $args[4]
}

#--- 作業フォルダ作成 ---
##$ErrorActionPreference = “Stop"
[bool] $flagNewDir = $false
if (-Not(Test-Path -LiteralPath $dirWorkFull -PathType Container)){
  New-Item $dirWorkFull -ItemType Directory
  if (! $?){
    Write-Host "Can't create ${dirWorkFull}"
    exit 1
  }
  $flagNewDir = $true  # 今回新規作成
}

#--- カレントディレクトリを作業場所に ---
$pathBakCurrentPwsh = Get-Location
$pathBakCurrentSys  = [IO.Directory]::GetCurrentDirectory()
Set-Location -LiteralPath "${dirWorkFull}"
[IO.Directory]::SetCurrentDirectory("${dirWorkFull}")

#--- TSファイル名が定義されていたらファイル作成 ---
if (-not [System.String]::IsNullOrWhiteSpace($pathTs)){
  [string] $pathWrite = Join-Path $dirWorkFull $fileList["pathTsPath"]
  Set-Content -LiteralPath $pathWrite -Value $pathTs -Encoding UTF8
}

#--- メイン実行 ---
$pathExe = Join-Path "${subdir}" "amtlog2jls.ps1"
& "${pathExe}" "$pathAmtLog"
$codeError = $LASTEXITCODE

#--- カレントディレクトリを戻す ---
Set-Location -LiteralPath "${pathBakCurrentPwsh}"
[IO.Directory]::SetCurrentDirectory("${pathBakCurrentSys}")

#--- 結果確認 ---
if ($codeError -ne 0){
  Write-Host "Can't get the expected data in Amatsukaze-log: " $pathAmtLog
  if ($flagNewDir){    # 今回作成した作業フォルダだった場合は削除
    Remove-Item $dirWorkFull -Recurse
  }
  exit 1
}

Write-Host "Create environment -- ${dirWorkFull}"
exit 0
