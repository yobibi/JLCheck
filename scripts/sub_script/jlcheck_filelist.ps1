#
# JLCheck ファイル名情報
#

$fileList = @{
  #--- Amatsukazeログから読み込んで出力する情報 ---
  "pathInScp"    = 'chapter_exe0.txt'
  "pathInLogo"   = 'logof0.txt'
  "pathNameStr"  = 'string_name.txt'
  "pathResLog"   = 'org_jlcheck0.txt'
  "pathBoot"     = 'go_jls.ps1'
  "nameTemplate" = 'template_go_jls.ps1'

  #---  Amatsukazeログ読み込み前に確定情報として設定 ---
  "pathTsPath"    = "tspath.txt"    # TS_IN_PATHに確定設定

  #--- 実行フローで必要なファイル情報 ---
  "nameResult"    = 'jlcheck0.txt'
  "nameSummary"   = 'sum_jlcheck.txt'
  "nameResOrg"    = 'org_jlcheck0.txt'   # pathResLogと同じにする
  "nameSumOrg"    = 'sum_org_jlcheck.txt'

  #--- 実行コマンド名 ---
  "nameAmtEnter"  = 'jlcheck_amt_enter.ps1'
  "nameMkEnv"     = 'jlcheck_amt_mkenv.ps1'
  "nameFilterIn"  = 'jlcheck_filter_in.ps1'
  "nameExeBoot"   = 'go_jls.ps1'
}
