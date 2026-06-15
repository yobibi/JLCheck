#
# [内容]
#   Amatsukazeログからjoin_logo_scp実行に必要な情報を取り出す
# [コマンド]
#   amtlog2jls.ps1 [filename]
# [引数]
#   [filename] : 読み込むAmatsukazeログのファイル名
# [返り値]
#   $LASTEXITCODE : 0=正常終了 1=データなし
# [出力]
#   chapter_exe0.txt : 無音シーンチェンジ情報
#   logof0.txt       : ロゴ区間情報
#   string_name.txt  : 内容識別文字列
#   org_jlcheck0.txt : ログのCM解析結果
#   go_jls.ps1       : CM解析(join_logo_scp)起動スクリプト
#   go_jls.bat       : powershellスクリプト実行用
# [使用スクリプト]
#   jlcheck_filelist.ps1  : ファイル名情報
#

#----------------------------------------------------------
# ファイル名設定
#----------------------------------------------------------
#--- 別ファイルから読み込み ---
$subdir        = "${PSScriptRoot}"
$pathFileList  = Join-Path $subdir "jlcheck_filelist.ps1"
. $pathFileList

#----------------------------------------------------------
# ファイル関連クラス
#----------------------------------------------------------
### <summary>
### ファイルの読み込みと書き込み（文字コード判定付き）を行うクラス
### </summary>
class FileProc
{
  $strNewLine       # 出力用改行コード
  $flagUtf8Bom      # 出力ファイル(UTF8)のBOM付加
  $bakStrNewLine
  $bakFlagUtf8Bom

  #----------------------------------------------------------
  # 書き込み時のBOM・改行コード変更
  #----------------------------------------------------------
  [void] ForceCode([bool] $crlf, [bool] $bom){
    if ($crlf){
      $this.strNewLine = "`r`n"
    }
    else{
      $this.strNewLine = "`n"
    }
    $this.flagUtf8Bom = $bom
  }
  [void] ReleaseCode(){
    $this.strNewLine  = $this.bakStrNewLine
    $this.flagUtf8Bom = $this.bakFlagUtf8Bom
  }
  # コンストラクタ
  # WindowsはCRLF,BOMあり、LinuxはLF,BOMなし
  FileProc(){
    if ([System.Environment]::OSVersion.Platform -eq 'Win32NT'){
      $this.ForceCode($true, $true)
    }
    else{
      $this.ForceCode($false, $false)
    }
    $this.bakStrNewLine  = $this.strNewLine
    $this.bakFlagUtf8Bom = $this.flagUtf8Bom
  }
  #----------------------------------------------------------
  # ファイルからテキスト読み込み
  #----------------------------------------------------------
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
  #----------------------------------------------------------
  # ファイルにテキスト書き込み
  #----------------------------------------------------------
  [void] WriteFileText([string] $pathWrite, [string[]] $textContent){
    $encodeType = New-Object System.Text.UTF8Encoding $this.flagUtf8Bom
    $strOut = $textContent -join $this.strNewLine
    #--- 最後の改行追加 ---
    $n = $textContent.Length
    if ($n -gt 0){
      $s = $textContent[$n-1]
      if ($s.Length -gt 0){
        $strOut += $this.strNewLine
      }
    }
    #--- ファイルに書き込み ---
    [System.IO.File]::WriteAllText($pathWrite, $strOut, $encodeType)
  }
}

#----------------------------------------------------------
# Amatsukazeログからjoin_logo_scp入力データを取り出す
#----------------------------------------------------------
#--- ログの現在地点ステータス ---
enum LogState {
  boot
  logo
  scp
  jlsin
  cmtrim
  cmdet
  intrim
  others
}
#--- 実行クラス ---
### <summary>
### Amatsukazeログからjoin_logo_scp入力データを取り出すクラス
### </summary>
class PickupJls : FileProc
{
  [LogState]    $stateCur   # 読込状態
  [hashtable]   $hashEnv    # 環境変数設定
  [string[]]    $textAmtLog # Amatsukazeログデータ
  [string[]]    $textLogo   # ロゴデータ位置ファイル出力用
  [string[]]    $textScp    # 無音シーンチェンジ位置ファイル出力用
  [string]      $pathCmd    # 指定JLスクリプトファイル名
  [int]         $nScpFrame  # (chapter_exe) 全体フレーム数
  [int]         $nScpNum    # (chapter_exe) 無音通し番号
  [string]      $strScpFrom # (chapter_exe) 無音開始位置時間文字列
  [string]      $strScpTerm # (chapter_exe) 無音期間情報文字列
  [string]      $strJlsExe  # join_logo_scp起動Path
  [string]      $strJlsIn   # 起動時JLスクリプト指定
  [string]      $strJlsOpt  # 起動時JLオプション指定
  [int]         $nUseLogo   # ロゴ使用設定
  [string[]]    $strCmTrim  # CM結果TrimAvs
  [string[]]    $textCmDiv  # CM結果Div
  [string[]]    $textCmDet  # CM結果詳細
  [bool]        $flagInTrim # Trim直接入力あり
  [bool]        $areaJlsDiv # 分割位置表示区間中

  # 初期値のセット
  [void] init(){
    $this.stateCur   = [LogState]::boot
    $this.hashEnv    = [ordered]@{}
    $this.textAmtLog = @()
    $this.textLogo   = @()
    $this.textScp    = @()
    $this.pathCmd    = 0
    $this.nScpFrame  = 0
    $this.nScpNum    = 0
    $this.strScpFrom = ''
    $this.strScpTerm = ''
    $this.strJlsExe  = 'join_logo_scp.exe'
    $this.strJlsIn   = 'JL_ANYSEL.txt'
    $this.strJlsOpt  = ''
    $this.nUseLogo   = 0
    $this.strCmTrim  = ''
    $this.textCmDiv  = @()
    $this.textCmDet  = @()
    $this.flagInTrim = $false
    $this.areaJlsDiv = $false
  }
  # コンストラクタ
  PickupJls(){
    $this.init()
  }

  #----------------------------
  # 時間情報の変換
  #----------------------------
  [int] ConvMsecFromFrame([int] $frame){
    $rate_n = 30000
    $rate_d = 1001
    $msec_frac = $frame * $rate_d * 1000 / $rate_n
    #--- chapter_exeと誤差近づける ---
    $tmp_powr = [Math]::Pow(2,14)
    $tmp_frac = $msec_frac / 1000
    $tmp_frac = [Math]::Floor($tmp_frac * $tmp_powr) / $tmp_powr
    $msec_frac = $tmp_frac * 1000
    #--- 誤差合わせ後にミリ秒で四捨五入 ---
    return [Math]::Round($msec_frac, 0, [MidpointRounding]::AwayFromZero)
  }
  [string] convTimeFromMsec([int] $msec){
    [int] $h = [Math]::Floor($msec/3600000)
    [int] $m = [Math]::Floor(($msec-$h*3600000)/60000)
    [int] $s = [Math]::Floor(($msec-$h*3600000-$m*60000)/1000)
    [int] $d = $msec % 1000
    $formatString = "{0,2:D2}:{1,2:D2}:{2,2:D2}.{3,3:D3}"
    return ($formatString -f $h,$m,$s,$d)
  }
  #----------------------------
  # 無音シーンチェンジファイル内容を作成
  #----------------------------
  #--- Amatsukazeログ結果からchapter_exe結果ファイル形式で取得 ---
  [void] GetScpIn([string] $strLine){
    if ($strLine -match '^mute\s*(\d+):\s*(\d+)\s*-\s*(\w+)'){
      # match例 : "mute 1: 186 - 37フレーム"
      $this.nScpNum = $Matches[1]       # 無音通し番号
      $this.strScpTerm = $Matches[3]    # フレーム期間文字列
      $msec = $this.ConvMsecFromFrame($Matches[2])  # 無音開始時間
      $this.strScpFrom = $this.convTimeFromMsec($msec)
    }
    elseif ($strLine -match '^\s*SCPos:\s*(\d+)\s*(.*)'){
      # match例 : "	 SCPos: 8114 ★★"
      [int] $scpos = $Matches[1]        # シーンチェンジフレーム
      [string] $mark = $Matches[2]      # マーク
      [int] $scpos_pre = $scpos - 1     # SCPos直前フレーム
      if ($mark -match '^(\d+)\s*(.*)'){
        # 手前位置情報が存在時の補正
        [int] $pos = $Matches[1]
        if (($pos -le $scpos) -and (($pos + 2) -ge $scpos)){
          $mark = $Matches[2]
          $scpos_pre = $pos
        }
      }
      #--- ファイル出力文字列 ---
      $formatString = 'CHAPTER{0,2:D2}={1}'
      $outputString = $formatString -f $this.nScpNum,$this.strScpFrom
      $this.textScp += $outputString    # 1行追加
      #--- ファイル出力文字列 ---
      $formatString = 'CHAPTER{0,2:D2}NAME={1} {2} SCPos:{3} {4}'
      $outputString = $formatString -f $this.nScpNum,$this.strScpTerm,$mark,$scpos,$scpos_pre
      $this.textScp += $outputString    # 1行追加
    }
    elseif ($strLine -match '^\s*CHAPTER(\d+)(NAME)?='){
      # ファイル出力形式だった場合はそのまま使用
      $this.textScp += $strLine
    }
    elseif ($strLine -match '^\s*# SCPos:(\d+)'){
      # ファイル出力形式の最終行
      $this.nScpFrame = ([int] $Matches[1]) + 1
    }
    elseif ($strLine -match 'Video Frames:\s*(\d+)'){
      # match例 : "	Video Frames: 54145 [29.97fps]"
      $this.nScpFrame = $Matches[1]     # 全体フレーム数を取得
    }
  }
  #--- inscpの最後に全体フレーム数を追加 ---
  [void] LastScpIn(){
    if ($this.nScpFrame -gt 0){  # 全体フレーム数情報がある場合は追加する
      #--- ファイル出力文字列 ---
      $formatString = '# SCPos:{0} {0}'
      $outputString = $formatString -f (([int]$this.nScpFrame)-1)
      $this.textScp += $outputString    # 1行追加
    }
  }
  #----------------------------
  # ロゴ区間ファイル内容を作成
  #----------------------------
  [void] GetLogoIn([string] $strLine){
    if ($strLine -match '^\s*\d+\s+\w+\s+\d+\s+\w+\s+\d+\s+\d+'){
      # match例 : "   209 S 0 ALL    145    209"
      #--- ファイル出力文字列 ---
      $this.textLogo += $strLine
    }
  }
  #----------------------------
  # AmatsukazeCLIの実行コマンドからデータ取得
  #----------------------------
  [void] GetVarFromCli([string] $strLine){
    if ($strLine -match ' -i "([^"]*)'){
      $this.hashEnv["CLI_IN_PATH"] = $Matches[1]
    }
    if ($strLine -match ' -s "?(\d+)'){
      $this.hashEnv["SERVICE_ID"] = $Matches[1]
    }
    if ($strLine -match ' -o "([^"]*)'){
      $this.hashEnv["CLI_OUT_PATH"] = $Matches[1]
    }
    if ($strLine -match ' --jls "([^"]*)'){
      $this.strJlsExe = $Matches[1]
    }
    if ($strLine -match ' --jls-cmd "([^"]*)'){
      $this.strJlsIn = $Matches[1]
    }
    if ($strLine -match ' --jls-option "(.*?)("\s+-.*)'){
      $select = $Matches[1]
      $remain = $Matches[2]
      do{
        $n = $select.Length - $select.Replace('"', '').Length
        if (($n % 2) -eq 1){  # 引用符は2個セット前提で、途中の時は次検索
          if ($remain -match '^(".*?)("\s+-.*)'){
            $select += $Matches[1]
            $remain = $Matches[2]
          }
          elseif ($remain -match '^(.*)"'){
            $select += $Matches[1]
            $remain = ''
          }
          else{
            $remain = ''
          }
        }
        else{
          $remain = ''
        }
      } while ($remain.Length -gt 0)
      $this.strJlsOpt = $select
    }
    elseif ($strLine -match ' --jls-option "(.*?)"\s*$'){
      $this.strJlsOpt = $Matches[1]
    }
  }
  #----------------------------
  # CM解析時ログ表示から環境変数データ取得
  #----------------------------
  [void] GetVarFromCm([string] $strInfo){
    if ($strInfo -match '^\s*([a-zA-Z][a-zA-Z_0-9]*)\s*:\s*([^\s].*)'){
      # match例 : "CLI_IN_PATH  : F:/test/タイトル _テレビ東京１.ts"
      $this.hashEnv[$Matches[1]] = $Matches[2]
    }
  }
  #----------------------------
  # CM解析結果を取得
  #----------------------------
  #--- CM解析結果Trimを取得 ---
  [void] GetJlsTrim([string] $strLine){
    if ($strLine -match 'Trim'){
      $this.strCmTrim = $strLine
    }
  }
  #--- CM解析結果詳細を取得 ---
  [void] GetJlsDetail([string] $strLine){
    if ($strLine -match '^\s*\d+\s+\d+'){
      # match例 : "     0    169    6  -9    0 :Nologo"
      $this.textCmDet += $strLine
    }
  }
  #--- 分割位置情報を取得 ---
  [void] GetJlsDivide([string] $strLine){
    if ($strLine -match '^join_logo_scp (\[.*?\])'){
      switch ( $Matches[1] ){
        '[分割位置 - 開始]' {
          $this.areaJlsDiv = $true
        }
        '[分割位置 - 終了]' {
          $this.areaJlsDiv = $false
        }
      }
    }
    elseif ($this.areaJlsDiv){
      if ($strLine -match '^(\d+)[^\w]*$'){
        $this.textCmDiv += $Matches[1]
      }
    }
  }
  #--- Trim直接指定時 ---
  [void] GetDirectTrim([string] $strLine){
    if ($strLine -match 'Trim'){
      $this.flagInTrim = $true
    }
  }
  #----------------------------
  # 各行デコード
  #----------------------------
  #--- 項目開始行 ---
  [void] DecodeFunc([string] $strName){
    switch ($strName){
      '[ロゴ解析結果]' {
        $this.stateCur = [LogState]::logo
      }
      '[無音・シーンチェンジ解析結果]' {
        $this.stateCur = [LogState]::scp
      }
      '[CM解析]' {
        $this.stateCur = [LogState]::jlsin
      }
      '[CM解析結果 - TrimAVS]' {
        $this.stateCur = [LogState]::cmtrim
      }
      '[CM解析結果 - 詳細]' {
        $this.stateCur = [LogState]::cmdet
      }
      '[Trim情報入力]' {
        $this.stateCur = [LogState]::intrim
      }
      default {
        $this.stateCur = [LogState]::others
      }
    }
  }
  #--- info情報行 ---
  [void] DecodeInfo([string] $strInfo){
    switch ($this.stateCur){
      "jlsin" {
        $this.GetVarFromCm($strInfo)  # 環境変数データ取得
      }
    }
  }
  #--- 一般行 ---
  [void] DecodeLine([string] $strLine){
    switch ($this.stateCur){
      "boot" {
        $this.GetVarFromCli($strLine)  # 実行コマンドからデータ取得
      }
      "logo" {
        $this.GetLogoIn($strLine)      # ロゴ区間ファイル内容を作成
      }
      "scp" {
        $this.GetScpIn($strLine)       # 無音シーンチェンジファイル内容を作成
      }
      "jlsin" {
        $this.GetJlsDivide($strLine)   # 分割位置情報を取得
      }
      "cmtrim" {
        $this.GetJlsTrim($strLine)     # CM解析結果Trimを取得
      }
      "cmdet" {
        $this.GetJlsDetail($strLine)   # CM解析結果詳細を取得
      }
      "intrim" {
        $this.GetDirectTrim($strLine)  # Trim直接入力を確認
      }
    }
  }
  #----------------------------
  # 読み込み開始
  #----------------------------
  [void] Analyze(){
    #--- Amatsukazeログを各行読み込み ---
    foreach($line in $this.textAmtLog){
      if ($line -match '^AMT \[info\] (\[.*?\])'){
        $this.DecodeFunc( $Matches[1] )
      }
      elseif ($line -match '^AMT \[info\] (.*)'){
        $this.DecodeInfo( $Matches[1] )
      }
      elseif ($line -match '^\d{4}\-\d{2}\-\d{2} \d{2}\:\d{2}\:\d{2} (.*)'){
        [string] $strParts = $Matches[1]
        if ($strParts -match '^(\[.*?\])'){
          $this.DecodeFunc( $Matches[1] )
        }
        else{
          $this.DecodeInfo( $strParts )
        }
      }
      else{
        $this.DecodeLine( $line )
      }
    }
    $this.LastScpIn()   # 無音シーンチェンジファイル最後に全体フレーム数追加
    if ($this.textLogo.Length -gt 0){
      $this.nUseLogo = 1   # ロゴあればロゴ使用
    }
  }
  #----------------------------
  # 処理開始
  #----------------------------
  [void] Start([string] $pathAmtLog){
    $this.textAmtLog = ([FileProc]$this).ReadFileText($pathAmtLog)
    $this.Analyze()
  }
  #--- TS名固定の場合は設定変更 ---
  [string] SetIfFixedTsPath([string] $pathTs, [string] $pathAmtLog){
    [string] $strIdent = ""
    if (Test-Path -LiteralPath $pathTs -PathType Leaf){
      [string[]] $textTmp = ([FileProc]$this).ReadFileText($pathTs)
      [string] $strTs = $textTmp[0]
      if (-not [System.String]::IsNullOrWhiteSpace($strTs)){
        $this.hashEnv["TS_IN_PATH"] = $strTs     # 環境設定
        [string] $str1 = [System.IO.Path]::GetFileName($strTs)
        [string] $str2 = [System.IO.Path]::GetFileName($pathAmtLog)
        $strIdent = $str1
        if ($str1 -ne $str2){
          $strIdent += ' @ ' + $str2
        }
      }
    }
    return $strIdent
  }
  #----------------------------
  # 結果をファイル出力
  #----------------------------
  #--- データ有無の確認 ---
  [bool] IsExistData(){
    if ($this.textScp.Length -eq 0){
      return $false
    }
    return $true
  }
  #--- 無音シーンチェンジ情報ファイル出力 ---
  [void] WriteScp([string] $pathInScp){
    if ($this.textScp.Length -gt 0){
      ([FileProc]$this).WriteFileText($pathInScp, $this.textScp)
    }
  }
  #--- ロゴ区間情報ファイル出力 ---
  [void] WriteLogo([string] $pathInLogo){
    if ($this.textLogo.Length -gt 0){
      ([FileProc]$this).WriteFileText($pathInLogo, $this.textLogo)
    }
  }
  #--- 内容認識文字列にファイル出力情報付加 ---
  [string[]] GetIdentHeader([string] $nameIdent){
    [string[]] $textSrc = @()
    [string] $strOne = '#(name) ' + $nameIdent
    $textSrc += $strOne
    return $textSrc
  }
  #--- 内容認識文字列にファイル出力情報付加（直接Trim入力情報あり） ---
  [string[]] GetIdentHeaderOrg([string] $nameIdent){
    [string[]] $textSrc = @()
    [string] $strOne = $this.GetIdentHeader($nameIdent)
    if ($this.flagInTrim){
      $strOne += " (DirectTrim)"
    }
    $textSrc += $strOne
    return $textSrc
  }
  #--- 内容認識文字列ファイル出力 ---
  [void] WriteNameStr([string] $pathNameStr, [string] $nameIdent){
    [string[]] $textSrc = $this.GetIdentHeader($nameIdent)
    ([FileProc]$this).WriteFileText($pathNameStr, $textSrc)
  }
  #--- CM解析結果ファイル出力 ---
  [void] WriteCmResultFromLog([string] $pathNameStr, [string] $nameIdent){
    [string[]] $textSrc = $this.GetIdentHeaderOrg($nameIdent)
    $textSrc += $this.strCmTrim
    if ($this.textCmDiv.Length -gt 0){
      $textSrc += $this.textCmDiv
    }
    $textSrc += $this.textCmDet
    ([FileProc]$this).WriteFileText($pathNameStr, $textSrc)
  }
  #--- 解析起動スクリプト出力 ---
  [void] WriteBoot([string] $pathBoot, [string] $pathTemplate){
    [string[]] $textSrc = ([FileProc]$this).ReadFileText($pathTemplate)
    [string[]] $textBoot = @()
    [bool] $flagUse = $true
    foreach ($line in $textSrc){
      #--- [indata]区間は差し替える処理 ---
      if ($line -match '^# \[indata\]'){
        $flagUse = $false   # 以降差し替え
        $textBoot += $line
        #--- 環境変数 ---
        $textBoot += '# (Amatsukaze-Log) 環境変数の設定'
        foreach ($key in $this.hashEnv.Keys) {
          $textBoot += '$env:{0} = ''{1}''' -f $key,$($this.hashEnv[$key].Replace("'", "''"))
        }
        $textBoot += ''
        #--- その他変数 ---
        $textBoot += '# (Amatsukaze-Log) join_logo_scp起動情報の設定'
        $textBoot += '$JLC_JLS = ''{0}''' -f $this.strJlsExe.Replace("'", "''");
        $textBoot += '$JLC_INCMD = ''{0}''' -f $this.strJlsIn.Replace("'", "''")
        $textBoot += '$JLC_OPTION = ''{0}''' -f $this.strJlsOpt.Replace("'", "''")
        $textBoot += '$JLC_USE_LOGO = {0}' -f $this.nUseLogo
        $textBoot += ''
      }
      elseif ($line -match '^# \['){  # 項目区切りで
        $flagUse = $true              # 以降使用する
      }
      if ($flagUse){
        $textBoot += $line
      }
    }
    # Windowsのpowershell5はBOMなしUTF8を読めないので共通で読めるように
    $this.ForceCode($true, $true)
    ([FileProc]$this).WriteFileText($pathBoot, $textBoot)
    $this.ReleaseCode()
  }
  #--- ps1 -> batに置換したファイル名のバッチファイル出力 ---
  [void] WriteBat([string] $pathBoot, [string] $pathTemplate){
    [string] $pathBatBoot = $pathBoot.Replace(".ps1", ".bat");
    [string] $pathBatTemplate = $pathTemplate.Replace(".ps1", ".bat");
    # .batが存在する時のみコピーする（なくても問題ない）
    if (Test-Path -LiteralPath $pathBatTemplate -PathType Leaf){
      [System.IO.File]::Copy($pathBatTemplate, $pathBatBoot, $true);
    }
  }
  #--- ps1 -> shに置換したファイル名のバッチファイル出力 ---
  [void] WriteSh([string] $pathBoot, [string] $pathTemplate){
    [string] $pathBatBoot = $pathBoot.Replace(".ps1", ".sh");
    [string] $pathBatTemplate = $pathTemplate.Replace(".ps1", ".sh");
    # .shが存在する時のみコピーする（なくても問題ない）
    if (Test-Path -LiteralPath $pathBatTemplate -PathType Leaf){
      [System.IO.File]::Copy($pathBatTemplate, $pathBatBoot, $true);
    }
  }
}

#----------------------------------------------------------
# 実行
#----------------------------------------------------------
#--- 入力ファイル名取得 ---
if ($args.Length -lt 1){
  Write-Host "Usage: amtlog2jls.ps1 [logFileName]"
  exit 1
}
$pathAmtLog = $args[0]

#--- カレントフォルダ設定 ---
[IO.Directory]::SetCurrentDirectory((Get-Location).Path)
#--- スクリプト場所設定 ---
$pathTemplate = Join-Path ${subdir} $($fileList["nameTemplate"])
#--- 識別名として出力する文字列設定 ---
$strIdentName = [System.IO.Path]::GetFileName((Get-Location).Path)

#--- Amatsukazeログからjoin_logo_scpに必要な情報取り出し ---
$pickupObj = New-Object PickupJls
$pickupObj.Start($pathAmtLog)
#--- 確定TS名が存在したら修正 ---
$strIdentTmp = $pickupObj.SetIfFixedTsPath($fileList["pathTsPath"], $pathAmtLog)
if (-not [System.String]::IsNullOrWhiteSpace($strIdentTmp)){
  $strIdentName = $strIdentTmp
}

#--- 結果出力 ---
if ($pickupObj.IsExistData()){
  $pickupObj.WriteScp($fileList["pathInScp"])
  $pickupObj.WriteLogo($fileList["pathInLogo"])
  $pickupObj.WriteNameStr($fileList["pathNameStr"], $strIdentName)
  $pickupObj.WriteCmResultFromLog($fileList["pathResLog"], $strIdentName)
  $pickupObj.WriteBoot($fileList["pathBoot"], $pathTemplate)
  $pickupObj.WriteBat($fileList["pathBoot"], $pathTemplate)
  $pickupObj.WriteSh($fileList["pathBoot"], $pathTemplate)
  exit 0     # 正常終了（エラーレベル=0）
}
exit 1   # 書き込みデータなし
