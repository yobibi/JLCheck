#
# [内容]
#   Amatsukazeログを入力データとしてjoin_logo_scp実行
# [コマンド]
#   jlcheck_cli.ps1 [filename] ...
#   jlcheck_cli.ps1 -logname [regexp1] -tspath [regexp2] -s [regexp3]
# [引数]
#   [filename] : 読み込むAmatsukazeログのファイル名
#   ...        : [filename]を複数並べて記載可能
#   [regexp1]  : 入力ログ名前部分のみで、正規表現にマッチするファイルのみ対象とする
#   [regexp2]  : 入力TSファイル名前部分でこの正規表現がマッチする場合のみ実施する
#   [regexp3]  : サービスIDが完全一致または正規表現マッチする時のみ実施する
#                -logpath,-tspath,-sいずれか定義で.jsonのTS名＋ログデータが対象になる
# [返り値]
#   $LASTEXITCODE : 0=正常終了 1=実行なし
# [出力]
#   $dirWorkBase/各入力引数のログ名前部分/*
#     - $dirWorkBaseは下記スクリプト内設定値
#     - 出力ファイル(*部分)はファイル名情報を参照
#   $dirWorkBase/sum_jlcheck.txt
#     - 各入力データのCM解析結果を１ファイルに結合したもの
#   $dirWorkBase/org_sum_jlcheck.txt
#     - 各入力データのAmatsukazeログ時点結果を１ファイルに結合したもの
# [使用スクリプト]
#   jlcheck_filelist.ps1  : ファイル名情報
#   jlcheck_amt_enter.ps1 : Amatsukazeログからjoin_logo_scp関連処理を実行
#   jlcheck_filter_in.ps1 : 正規表現マッチで入力を限定する
#   jlcheck_amt_mkenv.ps1 : Amatsukazeログからjoin_logo_scp実行に必要な環境作成
#   amtlog2jls.ps1        : Amatsukazeログからjoin_logo_scp実行に必要な情報取得
#   $dirWorkBase/各入力引数のログ名前部分/go_jls.ps1 : join_logo_scp実行
# [設定]
#   設定値部分を参照
#
#----------------------------------------------------------
# 設定値
#----------------------------------------------------------
#--- 実行設定 ---
$flowType  = "full"   # 環境作成(mkenv)から実行(gojls)まで

# $flowType  = "mkenv"  # join_logo_scp実行に必要な環境作成
# $flowType  = "mkenv2" # mkenvと違いは既に作業フォルダある時作成しない
# $flowType  = "gojls"  # 作成した環境でjoin_logo_scp実行
# $flowType  = "full"   # 環境作成(mkenv)から実行(gojls)まで
# $flowType  = "full2"  # 環境作成(mkenv2)から実行(gojls)まで

#--- 設定データ ---
$dataCliIn = @{
  "useXmlRead" = 0    # （0=外部設定読み込みなし 1=GUI版作成のXML優先）
  "dirWorkBase" = "${PSScriptRoot}/work_out"  # 読込ない時のベース作業フォルダ
  "dirJsonLog" = "${PSScriptRoot}/../data/logs" # Amatsukaze管理ログフォルダ
  "pathXml" = "${PSScriptRoot}/jlcheck_gui_config.xml" # XMLファイル名
}
#----------------------------------------------------------
# ファイル名設定
#----------------------------------------------------------
#--- 別ファイルから読み込み ---
[string] $subdir        = "${PSScriptRoot}/sub_script"
[string] $pathFileList  = Join-Path $subdir 'jlcheck_filelist.ps1'
. $pathFileList

#----------------------------------------------------------
# データ生成
#----------------------------------------------------------
class InDataProc
{
  [string] $exebase

  InDataProc(){
    #--- 固定データ設定 ---
    $this.exebase  = "${PSScriptRoot}"
  }
  #--- 文字列置換処理 ---
  [string] GetPathEval([string] $pathStr){
    $pathStr = $pathStr -replace '%exebase%', $this.exebase  # %exebase%を置換
    return $pathStr
  }
  #--- xmlファイルあれば設定を読み込む ---
  ReadXml($dat){
    if (Test-Path $dat["pathXml"] -PathType Leaf){  # ファイル存在時実行
      $xmlIn = [xml](Get-Content $dat["pathXml"])
      [string] $str = $xmlIn.jlcheck_xml.dir_work_base
      if ($str.length -gt 0){      # ベース作業フォルダの設定あれば差し替え
        $dat["dirWorkBase"] = $this.GetPathEval($str)
      }
    }
  }

  #--- 引数を加工（ログパス名をフルパスにする） ---
  [Object[]] ReviseArgs([Object[]] $orgArgs, [string] $dirJsonLog){
    [bool] $detectLogdata = $False
    [bool] $detectOption = $False
    [Object[]] $revisedArgs = $orgArgs
    for ($i=0; $i -lt $orgArgs.Length - 1; $i++){
      if ([System.String]::IsNullOrWhiteSpace($orgArgs[$i])){
      }
      elseif ($orgArgs[$i] -eq '-logname'){  # 管理ログ名にパス追加
        $revisedArgs[$i] = '-logpath'
        if ([System.String]::IsNullOrEmpty($orgArgs[$i+1])){
          $revisedArgs[$i+1] = Join-Path $dirJsonLog '.*'
        }
        else{
          $revisedArgs[$i+1] = Join-Path $dirJsonLog $orgArgs[$i+1]
        }
        $detectLogdata = $True
      }
      elseif ($orgArgs[$i] -eq '-logpath'){
        Write-Host 'Detect direct setting -logpath'
        $detectLogdata = $True
      }
      elseif ($orgArgs[$i] -eq '-tspath'){
        $detectOption = $True
      }
      elseif ($orgArgs[$i] -eq '-s'){
        $detectOption = $True
      }
      elseif ($orgArgs[$i].Substring(0, 1) -eq '-'){
        Write-Host 'Wrong Argument : ' $orgArgs[$i]
      }
    }
    # ログ名指定ないがAmatsukaze管理ログを使う場合はパス設定する
    if ((-not $detectLogdata) -and $detectOption){
      $revisedArgs += '-logpath'
      $revisedArgs += Join-Path $dirJsonLog '.*'
    }
    return $revisedArgs
  }
}

#----------------------------------------------------------
# 実行
#----------------------------------------------------------
#--- 引数確認 ---
if ($args.Length -lt 1){
  Write-Host "Need logFileName"
  exit 1
}
#--- データ生成クラス ---
[InDataProc] $procObj = New-Object InDataProc
#--- XML設定読み込み ---
if ($dataCliIn["useXmlRead"] -eq 1){
  $procObj.ReadXml($dataCliIn)      # 読み込み
}
#--- 入力引数加工 ---
[Object[]] $revisedArgs = $procObj.ReviseArgs($args, $dataCliIn["dirJsonLog"])
#--- 実行引数設定 ---
$listParam = @()
$listParam += '-flow'
$listParam += $flowType
$listParam += '-workbase'
$listParam += $dataCliIn["dirWorkBase"]
$listParam += $revisedArgs
#--- 実行 ---
[string] $pathAmtEnter = Join-Path $subdir $fileList["nameAmtEnter"]
& "$($pathAmtEnter)" @listParam
exit $LASTEXITCODE
