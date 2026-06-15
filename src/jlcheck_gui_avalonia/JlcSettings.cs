//
// Copyright (c) 2026 Yobi
// Released under the MIT License
// http://opensource.org/licenses/mit-license.php
//
//
// 設定データ保持
//
using Avalonia.Media;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Xml.Serialization;

namespace jlcheck_gui_avalonia
{
    /// <summary>
    /// 設定値名（文字列記述ミスがすぐわかるenumでレジスタを指定する）
    /// </summary>
    public enum ConfigReg
    {
        platform,
        dir_work_base,
        dir_subscript,
        dir_ini_inlog,
        editor,
        result,
        org_result,
        shell_cmd,
        shell_add,
        scr_mkenv,
        scr_gojls,
        edit_gojls,
        font_name,
        font_size,
        result_wrap,
    }
    /// <summary>
    /// 設定情報を保持するクラス
    /// </summary>
    public class JlcSettings
    {
        public class jlcheck_xml    // XMLファイルにこの名前で出力される
        {
            public string platform = "";         // 実行しているOS
            public string dir_work_base = "";    // 作業フォルダのベース位置
            public string dir_subscript = "";    // 各種スクリプトが置いてある場所
            public string dir_ini_inlog = "";    // Amatsukazeログ選択ダイアログ初期値
            public string editor = "";           // スクリプトを表示修正するエディタ名
            public string result = "";           // TextBoxに表示する結果のファイル名
            public string org_result = "";       // ログ時点結果のファイル名
            public string shell_cmd = "";        // スクリプト実行コマンド
            public string shell_add = "";        // スクリプト実行に付加する文字列
            public string scr_mkenv = "";        // 環境作成で起動するスクリプト名
            public string scr_gojls = "";        // join_logo_scp実行スクリプト名
            public string edit_gojls = "";       // join_logo_scp実行スクリプト名（Edit用）
            public string font_name = "";        // 結果表示用のフォント名
            public string font_size = "";        // 結果表示窓のフォントサイズ
            public string result_wrap = "";      // 結果表示を折り返す時は1
        }
        string nameEnvJlcXml = "JLCHECK_PATH_XML";     // XMLファイルパスの入った環境変数
        string nameJlcXml = "jlcheck_gui_config.xml";  // 環境変数未設定時のXMLファイル名
        string strSettingsLog = "";     // 設定内のエラーログ情報
        string dirExeBase = "";  // 起動時に現在実行しているプログラム場所の親フォルダを設定
        string pathJlcXml = "";  // 起動時にXMLファイル場所のフルパス名を設定
        List<string> listFontName = new List<string>();
        List<string> listDefaultFontName = new List<string> {  // フォントない時の候補
            "MS Gothic",
            "ＭＳ ゴシック",
            "Noto Sans Mono CJK JP",
        };
        jlcheck_xml dataXml = new jlcheck_xml();
        /// <summary>
        /// コンストラクタ
        /// </summary>
        public JlcSettings()
        {
            SetBaseFileName();
            InitSettings(true);
        }
        /// <summary>
        /// ファイル名等の固定文字列を作成
        /// </summary>
        private void SetBaseFileName()
        {
            string exePath = Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;
            string dirCurrent = System.IO.Path.GetDirectoryName(exePath) ?? string.Empty;
            dirExeBase = System.IO.Path.Combine(dirCurrent, @"../");
            pathJlcXml = Environment.GetEnvironmentVariable(nameEnvJlcXml) ?? "";
            if (string.IsNullOrWhiteSpace(pathJlcXml))
            {
                pathJlcXml = System.IO.Path.Combine(dirExeBase, nameJlcXml);
            }
            if (string.IsNullOrEmpty(exePath))
            {
                strSettingsLog += "EXEパスが取得できません\n";
            }
        }
        /// <summary>
        /// 初期設定値
        /// </summary>
        /// <param name="data"></param>
        private void InitDataXml(jlcheck_xml data)
        {
            data.platform = @"windows";
            data.dir_work_base = @"%exebase%/work_out";
            data.dir_subscript = @"%exebase%/sub_script";
            data.dir_ini_inlog = @"";
            data.editor = @"notepad";
            data.result = @"jlcheck0.txt";
            data.org_result = @"org_jlcheck0.txt";
            data.shell_cmd = "powershell";
            data.shell_add = "-ExecutionPolicy Bypass -File";
            data.scr_mkenv = @"jlcheck_amt_enter.ps1";
            data.scr_gojls = @"go_jls.ps1";
            data.edit_gojls = @"go_jls.ps1";
            data.font_name = @"MS Gothic";
            data.font_size = @"12";
            data.result_wrap = @"1";
            // 設置とOSが異なる時は強制的に変更する内容
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                data.platform = @"linux";
                data.shell_cmd = "pwsh";
                data.shell_add = "-File";
                //data.editor = @"gedit";
                data.editor = @"gnome-text-editor";
            }
        }
        /// <summary>
        /// XMLファイル読み込み
        /// </summary>
        /// <param name="data"></param>
        private void LoadDataXml(ref jlcheck_xml data)
        {
            try
            {
                XmlSerializer se = new XmlSerializer(typeof(jlcheck_xml));
                StreamReader sr = new StreamReader(pathJlcXml, new System.Text.UTF8Encoding(false));
                data = (jlcheck_xml)(se.Deserialize(sr) ?? "");
                sr.Close();
            }
            catch
            {
                strSettingsLog += $"XML読み出し({pathJlcXml})でエラー発生\n";
            }
        }
        /// <summary>
        /// XMLファイル書き込み
        /// </summary>
        /// <param name="data"></param>
        private void SaveDataXml(jlcheck_xml data)
        {
            try
            {
                XmlSerializer se = new XmlSerializer(typeof(jlcheck_xml));
                StreamWriter sw = new StreamWriter(pathJlcXml, false, new System.Text.UTF8Encoding(false));
                se.Serialize(sw, data);
                sw.Close();
            }
            catch
            {
                strSettingsLog += $"XML書き込みで({pathJlcXml})エラー発生\n";
            }
        }
        /// <summary>
        /// 初期設定で使用可能なフォント名一覧を取得して保持
        /// </summary>
        private void InitFontList()
        {
            listFontName.Clear();
#if AVALONIA
            var systemFontNames = FontManager.Current.SystemFonts;
            foreach (var font in systemFontNames)
            {
                listFontName.Add(font.Name);
            }
#else
            var systemFontNames = Fonts.SystemFontFamilies;
            foreach (var font in systemFontNames)
            {
                listFontName.Add(font.Source);
            }
#endif
        }
        /// <summary>
        /// 設定を初期化
        /// </summary>
        /// <param name="flagRead">false=初期値に設定  true=XMLファイルの値に設定</param>
        public void InitSettings(bool flagRead)
        {
            if (File.Exists(pathJlcXml) && flagRead)
            {
                LoadDataXml(ref dataXml);
                // 抜けあれば補間
                jlcheck_xml dataTmp = new jlcheck_xml();
                InitDataXml(dataTmp);
                if (string.IsNullOrEmpty(dataXml.dir_work_base)) dataXml.dir_work_base = dataTmp.dir_work_base;
                if (string.IsNullOrEmpty(dataXml.dir_subscript)) dataXml.dir_subscript = dataTmp.dir_subscript;
                if (string.IsNullOrEmpty(dataXml.dir_ini_inlog)) dataXml.dir_ini_inlog = dataTmp.dir_ini_inlog;
                if (string.IsNullOrEmpty(dataXml.editor)) dataXml.editor = dataTmp.editor;
                if (string.IsNullOrEmpty(dataXml.result)) dataXml.result = dataTmp.result;
                if (string.IsNullOrEmpty(dataXml.org_result)) dataXml.org_result = dataTmp.org_result;
                if (string.IsNullOrEmpty(dataXml.shell_cmd)) dataXml.shell_cmd = dataTmp.shell_cmd;
                if (string.IsNullOrEmpty(dataXml.shell_add)) dataXml.shell_add = dataTmp.shell_add;
                if (string.IsNullOrEmpty(dataXml.scr_mkenv)) dataXml.scr_mkenv = dataTmp.scr_mkenv;
                if (string.IsNullOrEmpty(dataXml.scr_gojls)) dataXml.scr_gojls = dataTmp.scr_gojls;
                if (string.IsNullOrEmpty(dataXml.edit_gojls)) dataXml.edit_gojls = dataTmp.edit_gojls;
                if (string.IsNullOrEmpty(dataXml.font_name)) dataXml.font_name = dataTmp.font_name;
                if (string.IsNullOrEmpty(dataXml.font_size)) dataXml.font_size = dataTmp.font_size;
                if (string.IsNullOrEmpty(dataXml.result_wrap)) dataXml.result_wrap = dataTmp.result_wrap;
                // platformが設定と違った時に強制変更する対象
                if (dataXml.platform != dataTmp.platform)
                {
                    dataXml.platform = dataTmp.platform;
                    dataXml.shell_cmd = dataTmp.shell_cmd;
                    dataXml.shell_add = dataTmp.shell_add;
                }
            }
            else
            {
                InitDataXml(dataXml);
                if (flagRead)  // XMLファイル読み込みできなかった時は新規作成
                {
                    SaveDataXml(dataXml);
                }
            }
            InitFontList();
        }
        /// <summary>
        ///  設定内容を保存
        /// </summary>
        public void SaveSettings()
        {
            SaveDataXml(dataXml);
        }
        /// <summary>
        /// ログ内容を呼び出し元に渡す
        /// </summary>
        /// <returns>ログ内容</returns>
        public string PopSettingsLog()
        {
            string strRet = strSettingsLog;
            strSettingsLog = "";
            return strRet;
        }
        /// <summary>
        /// 設定値を取得（展開なし）
        /// </summary>
        /// <param name="key">設定名</param>
        /// <returns>設定値</returns>
        public string GetSettingRaw(ConfigReg key)
        {
            string val;
            switch (key)
            {
                case ConfigReg.platform:
                    val = dataXml.platform;
                    break;
                case ConfigReg.dir_work_base:
                    val = dataXml.dir_work_base;
                    break;
                case ConfigReg.dir_subscript:
                    val = dataXml.dir_subscript;
                    break;
                case ConfigReg.dir_ini_inlog:
                    val = dataXml.dir_ini_inlog;
                    break;
                case ConfigReg.editor:
                    val = dataXml.editor;
                    break;
                case ConfigReg.result:
                    val = dataXml.result;
                    break;
                case ConfigReg.org_result:
                    val = dataXml.org_result;
                    break;
                case ConfigReg.shell_cmd:
                    val = dataXml.shell_cmd;
                    break;
                case ConfigReg.shell_add:
                    val = dataXml.shell_add;
                    break;
                case ConfigReg.scr_mkenv:
                    val = dataXml.scr_mkenv;
                    break;
                case ConfigReg.scr_gojls:
                    val = dataXml.scr_gojls;
                    break;
                case ConfigReg.edit_gojls:
                    val = dataXml.edit_gojls;
                    break;
                case ConfigReg.font_name:
                    val = dataXml.font_name;
                    break;
                case ConfigReg.font_size:
                    val = dataXml.font_size;
                    break;
                case ConfigReg.result_wrap:
                    val = dataXml.result_wrap;
                    break;
                default:
                    val = "";
                    break;
            }
            return val;
        }
        /// <summary>
        /// 設定値をbool値で取得
        /// </summary>
        /// <param name="key">設定名</param>
        /// <returns>設定値</returns>
        public bool GetSettingBool(ConfigReg key)
        {
            string val = GetSettingRaw(key);
            if (string.IsNullOrWhiteSpace(val))
            {
                return false;
            }
            if (val == "0") return false;
            return true;
        }
        /// <summary>
        /// 存在するフォント名リストを取得
        /// </summary>
        /// <returns>フォント名リスト</returns>
        public List<string> getFontFamilies()
        {
            return listFontName;
        }
        // 
        /// <summary>
        /// 実際のフォント名を確認して返す
        /// </summary>
        /// <param name="nameFont">指定フォント名</param>
        /// <returns>存在確認済みのフォント名</returns>
        public string getFontNameEval(string nameFont)
        {
            foreach (string nameItem in listFontName)  // 対象のフォント名が存在するか確認
            {
                if (string.Compare(nameItem, nameFont, true) == 0) return nameItem;
            }
            foreach (string nameCand in listDefaultFontName)  // デフォルトフォント名が存在するか確認
            {
                foreach (string nameItem in listFontName)
                {
                    if (string.Compare(nameItem, nameCand, true) == 0) return nameItem;
                }
            }
            return "";
        }
        /// <summary>
        /// 設定値を取得（展開あり）
        /// </summary>
        /// <param name="key">設定名</param>
        /// <returns>展開した設定値</returns>
        /// <example>
        /// 展開内容
        ///    %exebase% : 現在の実行プログラム場所
        ///    パス情報はフルパス
        ///    フォント名は使用可能なものに限定
        /// </example>
        public string GetSettingEval(ConfigReg key)
        {
            string val = GetSettingRaw(key);
            if (!string.IsNullOrEmpty(val))
            {
                val = val.Replace("%exebase%", dirExeBase);
                if (key == ConfigReg.dir_work_base || key == ConfigReg.dir_subscript)
                {
                    if (val.Length > 0)
                    {
                        val = System.IO.Path.GetFullPath(val);
                    }
                }
                if (key == ConfigReg.font_name)
                {
                    val = getFontNameEval(val);
                }
            }
            return val;
        }
        /// <summary>
        /// 設定値を取得（パスはスクリプトとして実行できる補完を行う）
        /// </summary>
        /// <param name="key">設定名</param>
        /// <returns>設定値</returns>
        public string GetScriptFullPath(ConfigReg key)
        {
            string val = GetSettingEval(ConfigReg.dir_subscript);
            string strName = GetSettingEval(key);
            val = System.IO.Path.Combine(val, strName);
            return val;
        }
        /// <summary>
        /// 作業用フォルダとなる名前生成
        /// </summary>
        /// <param name="strLog">入力ログ名</param>
        /// <returns>作業用フォルダ名</returns>
        public string GenerateWorkDirName(string strLog)
        {
            string dirRoot = GetSettingEval(ConfigReg.dir_work_base);
            string dirPart = System.IO.Path.GetFileNameWithoutExtension(strLog);
            return System.IO.Path.Combine(dirRoot, dirPart);
        }
        /// <summary>
        /// 設定値をセット
        /// </summary>
        /// <param name="key">設定名</param>
        /// <param name="val">設定値</param>
        public void SetSetting(ConfigReg key, string val)
        {
            switch (key)
            {
                case ConfigReg.platform:
                    dataXml.platform = val;
                    break;
                case ConfigReg.dir_work_base:
                    dataXml.dir_work_base = val;
                    break;
                case ConfigReg.dir_subscript:
                    dataXml.dir_subscript = val;
                    break;
                case ConfigReg.dir_ini_inlog:
                    dataXml.dir_ini_inlog = val;
                    break;
                case ConfigReg.editor:
                    dataXml.editor = val;
                    break;
                case ConfigReg.result:
                    dataXml.result = val;
                    break;
                case ConfigReg.org_result:
                    dataXml.org_result = val;
                    break;
                case ConfigReg.shell_cmd:
                    dataXml.shell_cmd = val;
                    break;
                case ConfigReg.shell_add:
                    dataXml.shell_add = val;
                    break;
                case ConfigReg.scr_mkenv:
                    dataXml.scr_mkenv = val;
                    break;
                case ConfigReg.scr_gojls:
                    dataXml.scr_gojls = val;
                    break;
                case ConfigReg.edit_gojls:
                    dataXml.edit_gojls = val;
                    break;
                case ConfigReg.font_name:
                    dataXml.font_name = val;
                    break;
                case ConfigReg.font_size:
                    dataXml.font_size = val;
                    break;
                case ConfigReg.result_wrap:
                    dataXml.result_wrap = val;
                    break;
                default:
                    val = "";
                    break;
            }
        }
        /// <summary>
        /// bool設定値をセット
        /// </summary>
        /// <param name="key">設定名</param>
        /// <param name="flag">設定値</param>
        public void SetSettingBool(ConfigReg key, bool? flag)
        {
            string val = (flag == true) ? "1" : "0";
            SetSetting(key, val);
        }
    }
}
