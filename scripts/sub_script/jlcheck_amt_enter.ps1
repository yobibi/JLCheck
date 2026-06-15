#
# [内容]
#   Amatsukazeログからjoin_logo_scp関連処理を実行
# [コマンド]
#   jlcheck_amt_enter.ps1 -flow [flowtype] -workbase [workbase] [filename] ...
#   jlcheck_amt_enter.ps1 -flow [flowtype] -workbase [workbase] -logpath [regexp1] -tspath [regexp2] -s [regexp3]
# [引数]
#   [flowtype] : 実行内容を指定する文字列。省略時は"mkenv"
#                  "mkenv"  : join_logo_scp実行に必要な環境作成
#                  "mkenv2" : mkenvと違いは既に作業フォルダある時作成しない
#                  "gojls"  : 作成した環境でjoin_logo_scp実行
#                  "full"   : 環境作成(mkenv)から実行(gojls)まで
#                  "full2"  : 環境作成(mkenv2)から実行(gojls)まで
#   [workbase] : ベース作業フォルダ。この下に作業フォルダが作成される
#   [filename] : 読み込むAmatsukazeログのファイル名（*を使用可能）
#   ...        : [filename]を複数並べて記載可能
#   [regexp1]  : 入力ログフルパスで、名前部分は正規表現にマッチするファイルのみ対象とする
#   [regexp2]  : 入力TSパスにこの正規表現がマッチする場合のみ実施する
#   [regexp3]  : サービスIDが正規表現マッチする時のみ実施する（文字列全体で一致が必要）
#                -logpath定義で.jsonのTS名＋ログデータが対象になる
# [返り値]
#   $LASTEXITCODE : 0=正常終了 1=実行なし
# [出力]
#   [workbase]/各入力引数のログ名前部分/*
#     - 出力ファイル(*部分)はファイル名情報を参照
#   [workbase]/sum_jlcheck.txt
#     - 各入力データのCM解析結果を１ファイルに結合したもの
#   [workbase]/sum_jlcheck.txt
#     - 各入力データのAmatsukazeログ時点結果を１ファイルに結合したもの
# [使用スクリプト]
#   jlcheck_filelist.ps1  : ファイル名情報
#   jlcheck_filter_in.ps1 : 正規表現マッチで入力を限定する
#   jlcheck_amt_mkenv.ps1 : Amatsukazeログからjoin_logo_scp実行に必要な環境作成
#   amtlog2jls.ps1        : Amatsukazeログからjoin_logo_scp実行に必要な情報取得
#   [workbase]/各入力引数のログ名前部分/go_jls.ps1 : join_logo_scp実行
#

#----------------------------------------------------------
# UTF-8出力
#----------------------------------------------------------
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#----------------------------------------------------------
# ファイル名設定
#----------------------------------------------------------
#--- 別ファイルから読み込み ---
[string] $subdir        = "${PSScriptRoot}"
[string] $pathFileList  = Join-Path $subdir 'jlcheck_filelist.ps1'
. $pathFileList

#----------------------------------------------------------
# ログファイル名からJSONファイル読み含め各種正規表現とマッチするファイルリスト作成
#----------------------------------------------------------
#--- 別ファイルから読み込み ---
[string] $pathFilterIn  = Join-Path $subdir $fileList["nameFilterIn"]
. $pathFilterIn

#----------------------------------------------------------
# 処理内容
#----------------------------------------------------------
### <summary>
### 作業フォルダ作成から作業フォルダ上でjoin_logo_scp実行まで行うクラス
### </summary>
class JlcAmtEnter
{
  [string] $subdir
  [string] $dirWorkBase
  [string] $dirWorkFull
  [string] $pathLogRegExp
  [string] $pathTsRegExp
  [string] $strServiceId
  [string] $nameMkEnv
  [string] $nameExeBoot
  [string] $nameResult
  [string] $nameSummary
  [string] $nameResOrg
  [string] $nameSumOrg
  [int]    $flowMkEnv
  [int]    $flowGoJls
  [bool]   $selectJson
  [bool]   $flagSummaryAppend
  [bool]   $flagSumOrgAppend
  [string[]] $listLogPath

  JlcAmtEnter(){
    #--- 初期値設定 ---
    $this.subdir        = "${PSScriptRoot}"
    $this.dirWorkBase   = Get-Location
    $this.dirWorkFull   = ''
    $this.pathLogRegExp = ''
    $this.pathTsRegExp  = '.*'
    $this.strServiceId  = ''
    $this.nameMkEnv     = 'jlcheck_amt_mkenv.ps1'
    $this.nameExeBoot   = 'go_jls.ps1'
    $this.nameResult    = 'jlcheck0.txt'
    $this.nameSummary   = 'sum_jlcheck.txt'
    $this.nameResOrg    = 'org_jlcheck0.txt'
    $this.nameSumOrg    = 'sum_org_jlcheck.txt'
    $this.flowMkEnv     = 1  # 作業環境作成（0=skip 1=実行 2=作業フォルダない時実行）
    $this.flowGoJls     = 0  # CM解析実行（0=しない 1=する）
    $this.selectJson    = $false
    $this.flagSummaryAppend  = $false
    $this.flagSumOrgAppend   = $false
    $this.listLogPath   = @()
  }
  #--- 文字列にマッチするファイル名すべて取得 ---
  [string []] GetListPathName([string] $pathSrc){
    [string []] $files = @()
    if (Test-Path -Path $pathSrc){
      $files = Get-ChildItem -Path $pathSrc
    }
    elseif (Test-Path -LiteralPath $pathSrc){
      $files += $pathSrc
    }
    else{
      # []は通常文字として扱うが*をワイルドカードにしたい時
      [string] $pathTmp = $pathSrc
      $pathTmp = $pathTmp.Replace('[', '``[')
      $pathTmp = $pathTmp.Replace(']', '``]')
      if (Test-Path -Path $pathTmp){
        $files = Get-ChildItem -Path $pathTmp
      }
      else{
        Write-Host "warning: not match path {0}" -f $pathSrc
      }
    }
    return $files
  }
  #--- 実行対象ログ名から作業ファイル名を決めて設定 ---
  [void] SetFullWorkPathByLogName([string] $pathLog){
    #--- ログファイル名から抜き出し ---
    [string] $dirPart = [System.IO.Path]::GetFileNameWithoutExtension($pathLog)
    #--- 全体のパス作成 ---
    [string] $dirFull = Join-Path $this.dirWorkBase $dirPart
    $this.dirWorkFull = $dirFull          # 作業フォルダ名を設定
  }
  #--- 作業環境を作成（別のスクリプト実行） ---
  [bool] RunMakeEnv([string] $pathLog, [string] $ts){
    [string] $pathExe = Join-Path $this.subdir $this.nameMkEnv
    if ([System.String]::IsNullOrWhiteSpace($ts)){
      & "${pathExe}" "${pathLog}" "-work" "$($this.dirWorkFull)"
    }
    else{
      & "${pathExe}" "${pathLog}" "-work" "$($this.dirWorkFull)" "-ts" "${ts}"
    }
    if ($LASTEXITCODE -eq 0){
      return $true
    }
    return $false
  }
  #--- join_logo_scpの実行 ---
  [bool] RunGoJls(){
    [string] $pathExeBoot = Join-Path $this.dirWorkFull $this.nameExeBoot
    #--- 実行ファイルが存在したらCM解析を実行 ---
    if (Test-Path -LiteralPath $pathExeBoot -PathType Leaf){
      & "${pathExeBoot}"
    }
    else{
      Write-Host "(Not Exist) Skip to run ${pathExeBoot} at $($this.dirWorkFull)"
      return $false
    }
    return $true
  }
  #--- 結果を結合するため最初の処理 ---
  [void] InitResult(){
    [string] $pathSummary = Join-Path $this.dirWorkBase $this.nameSummary
    [string] $pathSumOrg  = Join-Path $this.dirWorkBase $this.nameSumOrg
    if (Test-Path -LiteralPath $pathSummary -PathType Leaf){
      Remove-Item $pathSummary
    }
    if (Test-Path -LiteralPath $pathSumOrg -PathType Leaf){
      Remove-Item $pathSumOrg
    }
    $this.flagSummaryAppend = $false
    $this.flagSumOrgAppend = $false
  }
  #--- 結果を結合する処理 ---
  [bool] AppendResult(){
    [bool] $flagRun = $false
    [string] $pathSummary = Join-Path $this.dirWorkBase $this.nameSummary
    [string] $pathSumOrg  = Join-Path $this.dirWorkBase $this.nameSumOrg
    [string] $pathResult  = Join-Path $this.dirWorkFull $this.nameResult
    [string] $pathResOrg  = Join-Path $this.dirWorkFull $this.nameResOrg
    #--- 今回実行した結果を結合 ---
    if (Test-Path -LiteralPath $pathResult -PathType Leaf){
      $flagRun = $true
      if ($this.flagSummaryAppend){
        Add-Content -LiteralPath $pathSummary -Value ""  # 1行あける
        Get-Content $pathResult | Add-Content -LiteralPath $pathSummary
      }
      else{
        Get-Content $pathResult | Set-Content -LiteralPath $pathSummary -Encoding UTF8
        $this.flagSummaryAppend = $true
      }
    }
    #--- Amatsukazeログ時の結果を結合 ---
    if (Test-Path -LiteralPath $pathResOrg -PathType Leaf){
      if ($this.flagSumOrgAppend){
        Add-Content -LiteralPath $pathSumOrg -Value ""  # 1行あける
        Get-Content $pathResOrg | Add-Content -LiteralPath $pathSumOrg
      }
      else{
        Get-Content $pathResOrg | Set-Content -LiteralPath $pathSumOrg -Encoding UTF8
        $this.flagSumOrgAppend = $true
      }
    }
    return $flagRun
  }
  #--- １ファイル実行（環境作成） ---
  [int] RunOneFileEnv([string] $pathAmtLog, [string] $ts, [int] $count){
    #--- 作業フォルダ名を設定 ---
    $this.SetFullWorkPathByLogName($pathAmtLog)
    #--- flow設定により、無条件実行と、ディレクトリない時のみ実行 ---
    [bool] $existWork = Test-Path -LiteralPath $this.dirWorkFull -PathType Container
    if (($this.flowMkEnv -eq 1) -or (($this.flowMkEnv -eq 2) -and (-not $existWork))){
      [bool] $flagRun = $this.RunMakeEnv($pathAmtLog, $ts)
      if ($flagRun){
        $count += 1
      }
    }
    return $count
  }
  #--- １ファイル実行（GoJls） ---
  [int] RunOneFileGoJls([int] $count){
    #--- flow設定により、CM解析を行う時のみ実行 ---
    if ($this.flowGoJls -gt 0){
      [bool] $flagRun = $this.RunGoJls()   # join_logo_scp実行
      if ($flagRun){
        [bool] $flagSum = $this.AppendResult()  # 結果を１ファイルにまとめ
        if ($flagSum){
          $count += 1
        }
      }
    }
    return $count
  }
  #----------------------------------------------------------
  # 外部I/Fとなるpublic関数
  #----------------------------------------------------------
  #--- ファイル名の設定 ---
  [void] SetFileName($fileList){
    $this.nameMkEnv   = $fileList["nameMkEnv"]
    $this.nameExeBoot = $fileList["nameExeBoot"]
    $this.nameResult  = $fileList["nameResult"]
    $this.nameSummary = $fileList["nameSummary"]
    $this.nameResOrg  = $fileList["nameResOrg"]
    $this.nameSumOrg  = $fileList["nameSumOrg"]
  }
  #--- 実行フローを設定 ---
  [bool] SetFlowType([string] $flowtype){
    [bool] $valid = $true
    switch($flowtype){
      'mkenv' {
        $this.flowMkEnv = 1
        $this.flowGoJls = 0
      }
      'mkenv2' {
        $this.flowMkEnv = 2
        $this.flowGoJls = 0
      }
      'gojls' {
        $this.flowMkEnv = 0
        $this.flowGoJls = 1
      }
      'full' {
        $this.flowMkEnv = 1
        $this.flowGoJls = 1
      }
      'full2' {
        $this.flowMkEnv = 2
        $this.flowGoJls = 1
      }
      default {
        $valid = $false
      }
    }
    return $valid
  }
  #--- ベース作業フォルダを設定 ---
  [bool] SetWorkBase([string] $strDir){
    if ([System.String]::IsNullOrWhiteSpace($strDir)){
      return $false
   }
    $this.dirWorkBase = $strDir
    return $true
  }
  #--- 入力Amatsukazeログファイル名を追加 ---
  [bool] AddLogoPath([string] $pathLog){
    $listPath = $this.GetListPathName($pathLog)
    if ($listPath.Length -eq 0){
      return $false;
    }
    $this.listLogPath += $listPath
    return $true
  }
  #--- Amatsukaze管理ログファイル名を指定 ---
  [bool] SetJsonLogPath([string] $pathLog){
    $this.pathLogRegExp = $pathLog
    $this.selectJson = $true
    return $true
  }
  #--- Amatsukaze管理ログ内のTSファイル名を指定 ---
  [bool] SetJsonTsPath([string] $pathTs){
    $this.pathTsRegExp = $pathTs
    $this.selectJson = $true
    return $true
  }
  #--- サービスIDを指定 ---
  [bool] SetServiceId([string] $sid){
    $this.strServiceId = $sid
    $this.selectJson = $true
    return $true
  }
  #--- 実行開始 ---
  [int] RunEnter(){
    $nSumMkenv  = 0
    $nSumOutput = 0
    #--- 結果全体を結合する場合のファイル初期化 ---
    if ($this.flowGoJls -gt 0){    # CM解析を行う設定の場合
      $this.InitResult()
    }
    #--- Amatsukaze管理ログ指定時は対象ファイルリストをここで作成して実行 ---
    if ($this.selectJson){
      $filterObj = New-Object FilterJsonProc
      $filterObj.SetMatchLogList($this.pathLogRegExp, $this.pathTsRegExp, $this.strServiceId)
      $listLogts = $filterObj.GetListLogTs()
      foreach ($logts in $listLogts){
        $nSumMkenv = $this.RunOneFileEnv($logts.logpath, $logts.tspath, $nSumMkenv)
        $nSumOutput = $this.RunOneFileGoJls($nSumOutput)
      }
    }
    else{   # 単体ログファイル指定時の処理
      [string] $ts = ""
      foreach($pathAmtLog in $this.listLogPath){  # 入力ログ全部実施
        $nSumMkenv = $this.RunOneFileEnv($pathAmtLog, $ts, $nSumMkenv)
        $nSumOutput = $this.RunOneFileGoJls($nSumOutput)
      }
    }
    if ($this.flowMkEnv -gt 0){  # 作業環境を作成する設定の場合
      Write-Host "Total New Workspace : ${nSumMkenv}"
    }
    if ($this.flowGoJls -gt 0){    # CM解析を行う設定の場合
      Write-Host "Total Analyzed Data : ${nSumOutput}"
      return ${nSumOutput}
    }
    return ${nSumMkenv}
  }
}

#----------------------------------------------------------
# 実行
#----------------------------------------------------------
#--- 引数確認 ---
if ($args.Length -lt 1){
  Write-Host "Need Argument(logFileName)"
  exit 1
}
#--- 引数内容を設定 ---
Enum ArgNext {
  Normal
  Flow
  WorkBase
  LogPath
  TsPath
  Sid
}
try{
[JlcAmtEnter] $enterObj = New-Object JlcAmtEnter
#--- ファイル名情報をクラス内に設定 ---
$enterObj.SetFileName($fileList)   # ファイル名を読み込み設定
#--- 個別引数 ---
[ArgNext] $next = [ArgNext]::Normal
foreach($s in $args){
  if ($s -eq '-flow'){
    $next = [ArgNext]::Flow
  }
  elseif ($s -eq '-workbase'){
    $next = [ArgNext]::WorkBase
  }
  elseif ($s -eq '-logpath'){
    $next = [ArgNext]::LogPath
  }
  elseif ($s -eq '-tspath'){
    $next = [ArgNext]::TsPath
  }
  elseif ($s -eq '-s'){
    $next = [ArgNext]::Sid
  }
  elseif ($next -eq [ArgNext]::Flow){
    $valid = $enterObj.SetFlowType($s)   # 実行フローを設定
    $next = [ArgNext]::Normal
  }
  elseif ($next -eq [ArgNext]::WorkBase){
    $valid = $enterObj.SetWorkBase($s)   # ベース作業フォルダを設定
    $next = [ArgNext]::Normal
  }
  elseif ($next -eq [ArgNext]::LogPath){
    $valid = $enterObj.SetJsonLogPath($s)   # 管理ログファイル名を指定
    $next = [ArgNext]::Normal
  }
  elseif ($next -eq [ArgNext]::TsPath){
    $valid = $enterObj.SetJsonTsPath($s)   # 管理ログ内のTSファイル名を指定
    $next = [ArgNext]::Normal
  }
  elseif ($next -eq [ArgNext]::Sid){
    $valid = $enterObj.SetServiceId($s)   # 管理ログ内のTSファイル名を指定
    $next = [ArgNext]::Normal
  }
  else{
    $valid = $enterObj.AddLogoPath($s)   # Amatsukazeログへのパス設定
  }
}
#--- 実行 ---
[int] $nCount = $enterObj.RunEnter()
}
catch{
  Write-Host "エラー発生"
  Write-Output $_
}
if ($nCount -eq 0){  # 実行カウント=0
  exit 1
}
exit 0
