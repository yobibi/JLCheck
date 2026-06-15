#
# [内容]
#   ソース分割扱いで、ソース内に追加する
#   ログファイル名からJSONファイル読み含め各種正規表現とマッチするファイルリスト作成
#   ログファイル名とTSファイル名とサービスIDを正規表現でフィルター
# [関数]
#   SetMatchLogList([string] $pathLogRegExp, [string] $regExpTs, [string] $sid)
#     $pathLogRegExp  : ログファイル名のフルパス
#     $regExpTs       : TS名でフィルターする正規表現
#     $sid            : サービスIDでフィルターする正規表現
#     ログファイルと対応するjsonファイル情報も使って正規表現でフィルターする
#     マッチしたらログファイル名を内部リストに追加する
#
#   GetListLogTs()
#     フィルター後に残ったログファイル名リストを返す
#
#   GetMatchStatus()
#     3種類のフィルタそれぞれ順番に実行後残った候補数を文字列で返す
#
#----------------------------------------------------------
# ログファイル名からJSONファイル読み含め各種正規表現とマッチするファイルリスト作成
#----------------------------------------------------------
### <summary>
### ログファイル名からJSONファイル読み含め各種正規表現とマッチするファイルリスト作成
### </summary>
class LogTsInfo
{
  [string] $logpath
  [string] $tspath
  LogTsInfo([string] $log, [string] $ts){
    $this.logpath = $log
    $this.tspath = $ts
  }
}
class FilterJsonProc
{
  #--- 結果保管 ---
  $listLogTs = [System.Collections.Generic.List[LogTsInfo]]::new()
  AddLogTs([string] $log, [string] $ts){
    $this.listLogTs.Add([LogTsInfo]::new($log, $ts))
  }
  #--- マッチ数の保管 ---
  [int] $countLog = 0
  [int] $countTs  = 0
  [int] $countSid = 0
  #--- ファイルからテキスト読み込み ---
  [string[]] ReadFileText([string] $pathRead){
    $bytes = [System.IO.File]::ReadAllBytes($pathRead)

    $dat = ""
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      $dat = [System.Text.Encoding]::UTF8.GetString($bytes[3..$bytes.Length])  # UTF-8 (BOM付き)
    } elseif ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
      $dat = [System.Text.Encoding]::GetEncoding("utf-16").GetString($bytes[2..$bytes.Length])  # (UTF-16 LE)
    } elseif ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
      $dat = [System.Text.Encoding]::GetEncoding("unicodeFFFE").GetString($bytes[2..$bytes.Length])  # (UTF-16 BE)
    } else {
      #--- BOMなし時 UTF-8 or Shift-JIS ---
      $flagUtf8 = $True
      $utf8Content = [System.Text.Encoding]::UTF8.GetString($bytes)
      $decodedUtf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($utf8Content)
      if (($bytes.Length -ne $decodedUtf8Bytes.Length) -or ($bytes -xor $decodedUtf8Bytes)){
        $sjisContent = [System.Text.Encoding]::GetEncoding("shift_jis").GetString($bytes)
        $decodedSjisBytes = [System.Text.Encoding]::GetEncoding("shift_jis").GetBytes($sjisContent)
        $difSjis = $decodedSjisBytes.Length - $bytes.Length
        $difUtf8 = $decodedUtf8Bytes.Length - $bytes.Length
        if ([Math]::Abs($difSjis) -lt [Math]::Abs($difUtf8)){
          $flagUtf8 = $False
          $dat = $sjisContent  # Shift-JIS
        }
      }
      if ($flagUtf8){
        $dat = $utf8Content  # UTF-8
      }
    }
    return ($dat -split "`r?`n")
  }
  #--- Jsonファイルからsrcpath文字列を取り出し ---
  [string] GetTsPath([string] $pathJson){
    # [注釈] PowerShell5系ではUTF8Nを直接読み込めないので独自関数で
    [string[]] $textJson = $this.ReadFileText($pathJson)
    $data = $textJson -join "" | ConvertFrom-Json
    return $data.srcpath
  }
  #--- Jsonファイルの文字列が正規表現とマッチするか ---
  [bool] IsMatchTsPath([string] $tspath, [string] $regExp){
    $res = $tspath -match $regExp
    return $res
  }
  #--- ログデータファイル名をJsonデータファイル名から取得 ---
  [string] GetLogPath([string] $pathJson){
    return $pathJson -replace '(.*).json', '$1.txt'
  }
  #--- Jsonファイル名リストを取得 ---
  [string[]] GetJsonFileList([string] $pathLog){
    [string []] $files = @()
    [string] $dir = Split-Path $pathLog -Parent
    [string] $checkPath = Join-Path $dir '*.json'
    if (Test-Path -Path $checkPath){
      $files = Get-ChildItem -Path $checkPath
    }
    return $files
  }
  #--- サービスIDを取得 ---
  [string] GetServiceId([string] $pathLog){
    [string] $sid = ""
    [string[]] $textLog = $this.ReadFileText($pathLog)
    if (-not [System.String]::IsNullOrWhiteSpace($textLog)){
      [string] $strCmd = $textLog[0]
      if ($strCmd -match ' -s (\w+)'){
        $sid = $Matches[1]
      }
    }
    return $sid
  }
  #--- 正規表現でなかった場合、全体が一致する表現に変更  ---
  [string] GetFullMatchString([string] $src){
    if (-not ($src -match "[.\*?+^`$\[\]\(\)\{\}\|]")){
      $src = '^' + $src + '$'
    }
    return $src
  }
  #----------------------------------------------------------
  # 外部I/Fとなるpublic関数
  #----------------------------------------------------------
  #--- 保管データ取得 ---
  [LogTsInfo[]] GetListLogTs(){
    return $this.listLogTs
  }
  #--- マッチ情報を文字列で返す ---
  [string] GetMatchStatus(){
    [string] $formatString = "Match Count Log={0} -> TS={1} -> ServiceID={2}"
    return ($formatString -f $this.countLog , $this.countTs , $this.countSid)
  }
  #--- 正規表現にマッチするログリストを取得し保管 ---
  [void] SetMatchLogList([string] $pathLogRegExp, [string] $regExpTs, [string] $sid){
    [string] $regExpLog = Split-Path $pathLogRegExp -Leaf
    [string []] $listMatchLog = @()
    [string []] $listJson = $this.GetJsonFileList($pathLogRegExp)
    foreach ($pathJson in $listJson){
      [string] $pathLog = $this.GetLogPath($pathJson)
      [string] $nameLog = Split-Path $pathLog -Leaf
      if ($nameLog -match $regExpLog){
        $this.countLog += 1
        if (Test-Path -LiteralPath $pathLog){
          [string] $pathTs = $this.GetTsPath($pathJson)
          [string] $nameTs = [System.IO.Path]::GetFileName($pathTs)
          if ($this.IsMatchTsPath($nameTs, $regExpTs)){
            $this.countTs += 1
            $logSid = ''
            if (-not [System.String]::IsNullOrWhiteSpace($sid)){
              $logSid = $this.GetServiceId($pathLog)
              $sid = $this.GetFullMatchString($sid)
            }
            if (($sid -eq '') -or ($logSid -match $sid)){
              $this.countSid += 1
              $this.AddLogTs($pathLog, $pathTs)
            }
          }
        }
      }
    }
  }
}
