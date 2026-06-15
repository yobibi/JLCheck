//
// Copyright (c) 2026 Yobi
// Released under the MIT License
// http://opensource.org/licenses/mit-license.php
//
//
// データ処理
//
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

using UserDialogSet;

namespace jlcheck_gui_w
{
    /// <summary>
    /// 入力用テキストボックスのハイライト種類
    /// </summary>
    public enum MsgColorSelect   // 入力用テキストボックスのハイライト種類
    {
        None = 0,             // 通常
        NoData,               // 未入力
        WrongData,            // 誤データ
    }
    /// <summary>
    /// データ処理クラス
    /// </summary>
    public class JlcFuncData
    {
        JlcSettings settingsRef;       // 設定データ参照先
        Window parent;                 // 親ウィンドウ
        /// <summary>
        /// コンストラクタ
        /// </summary>
        /// <param name="settings"></param>
        /// <param name="parentIn"></param>
        public JlcFuncData(JlcSettings settings, Window parentIn)
        {
            settingsRef = settings;
            parent = parentIn;
        }
        //----------------------------------------------------------
        // ファイル処理
        //----------------------------------------------------------
        /// <summary>
        /// パスとファイル名を合わせたファイル名取得（作業フォルダはワイルドカードで複数可能）
        /// </summary>
        /// <param name="dirIn">フォルダ名部分</param>
        /// <param name="strName">ファイル名前部分</param>
        /// <returns></returns>
        public List<string> GetListMatchPath(string dirIn, string strName)
        {
            List<string> listExePath = new List<string>();
            if (string.IsNullOrWhiteSpace(dirIn))
            {
                return listExePath;
            }
            if (dirIn.EndsWith(@"\") || dirIn.EndsWith("/"))
            {
                dirIn = dirIn.Substring(0, dirIn.Length - 1);
            }
            if (dirIn.EndsWith(@"\") || dirIn.EndsWith("/"))
            {
                dirIn = dirIn.Substring(0, dirIn.Length - 1);
            }
            string dirBase = System.IO.Path.GetDirectoryName(dirIn) ?? "";
            string dirLast = System.IO.Path.GetFileName(dirIn);
            if (!System.IO.Directory.Exists(dirBase))
            {
                return listExePath;
            }
            string[] listDir = System.IO.Directory.GetDirectories(dirBase, dirLast);
            foreach (string oneDir in listDir)
            {
                string[] files = System.IO.Directory.GetFiles(oneDir, strName);
                foreach (string file in files)
                {
                    listExePath.Add(file);
                }
            }
            return listExePath;
        }
        /// <summary>
        /// TextBox書き込み共通の処理（指定パスにマッチするファイル全部のテキスト出力を連結）
        /// </summary>
        /// <param name="textbox">書き込み先テキスト制御</param>
        /// <param name="pathDirWorkBase">ベース作業フォルダ名</param>
        /// <param name="nameRead">ファイル名前部分</param>
        private void WriteTextDispFromPath(TextBox textbox, string pathDirWorkBase, string nameRead)
        {
            List<string> listPath = GetListMatchPath(pathDirWorkBase ?? "", nameRead);
            if (listPath.Count > 0)
            {
                textbox.Text = "";
                foreach (string pathResult in listPath)
                {
                    textbox.Text += File.ReadAllText(pathResult);
                }
            }
            else
            {
                textbox.Text = "Not Exist";
            }
        }
        /// <summary>
        /// CM解析結果を対象ウィンドウに書き込み
        /// </summary>
        /// <param name="textbox">書き込み先テキスト制御</param>
        /// <param name="pathDirWorkBase">ベース作業フォルダ</param>
        public void WriteTextDispResult(TextBox textbox, string pathDirWorkBase)
        {
            string nameResult = settingsRef.GetSettingEval(ConfigReg.result);  // "jlcheck0.txt"
            WriteTextDispFromPath(textbox, pathDirWorkBase, nameResult);
        }
        /// <summary>
        /// ログ時点解析結果を対象ウィンドウに書き込み
        /// </summary>
        /// <param name="textbox">書き込み先テキスト制御</param>
        /// <param name="pathDirWorkBase">ベース作業フォルダ</param>
        public void WriteTextDispOriginal(TextBox textbox, string pathDirWorkBase)
        {
            string nameOriginal = settingsRef.GetSettingEval(ConfigReg.org_result);
            WriteTextDispFromPath(textbox, pathDirWorkBase, nameOriginal);
        }
        /// <summary>
        /// ログ入力ファイルをダイアログを使って選択
        /// </summary>
        /// <param name="textbox">書き込み先テキスト制御</param>
        /// <returns>選択されたファイル名</returns>
        public async Task SelectPathAmtLogByDialogAsync(TextBox textbox)
        {
            FileDialogOptionsInfo optDialog = new FileDialogOptionsInfo(parent);
            optDialog.title = "Amatsukazeログ選択";
            optDialog.iniDir = settingsRef.GetSettingEval(ConfigReg.dir_ini_inlog);
            optDialog.filter.Add(("logファイル(*.log)", "*.log"));
            optDialog.filter.Add(("text/logファイル(*.log *.txt)", "*.log;*.txt"));
            optDialog.withAllFilter = true;
            string pathSel = await FileDialog.OpenFileAsync(optDialog);
            if (!String.IsNullOrWhiteSpace(pathSel))
            {
                textbox.Text = pathSel;
            }
        }
        /// <summary>
        /// 作業フォルダをダイアログを使って選択
        /// </summary>
        /// <param name="textbox">書き込み先テキスト制御</param>
        /// <returns>選択されたフォルダ名</returns>
        public async Task SelectPathDirWorkByDialogAsync(TextBox textbox)
        {
            FileDialogOptionsInfo optDialog = new FileDialogOptionsInfo(parent);
            optDialog.title = "作業フォルダ選択";
            optDialog.iniDir = settingsRef.GetSettingEval(ConfigReg.dir_work_base);
            string dirSel = await FileDialog.OpenFolderAsync(optDialog);
            if (!String.IsNullOrWhiteSpace(dirSel))
            {
                textbox.Text = dirSel;
            }
        }
        //----------------------------------------------------------
        // 属性処理
        //----------------------------------------------------------
        /// <summary>
        /// フォント設定
        /// </summary>
        /// <param name="textBox">対象テキスト制御</param>
        /// <param name="strFontName">フォント名</param>
        private void ChangeTxtFontFamily(TextBox textBox, string strFontName)
        {
            if (!string.IsNullOrEmpty(strFontName))
            {
#if AVALONIA
                textBox.FontFamily = new FontFamily(strFontName);
#else
                textBox.FontFamily = new System.Windows.Media.FontFamily(strFontName);
#endif
            }
        }
        /// <summary>
        /// 背景色を取得
        /// </summary>
        /// <returns>背景色情報</returns>
        private Brush GetBackColor()
        {
            if (parent != null)
            {
                if (parent.Background != null)
                {
                    return (Brush)parent.Background;  // 通常はこの設定
                }
            }
            return new SolidColorBrush(Colors.White); // null可能性の保険設定
        }
        /// <summary>
        /// 入力用テキストボックスをハイライト
        /// </summary>
        /// <param name="textBox">対象テキスト制御</param>
        /// <param name="selType">ハイライト種類</param>
        public void ChangeTxtBackColor(TextBox textBox, MsgColorSelect selType)
        {
            switch (selType)
            {
                case MsgColorSelect.NoData:
                    textBox.Background = new SolidColorBrush(Colors.LightYellow);
                    break;
                case MsgColorSelect.WrongData:
                    textBox.Background = new SolidColorBrush(Colors.Orange);
                    break;
                default:
                    textBox.Background = GetBackColor();
                    break;
            }
        }
        /// <summary>
        /// テキストボックスの書式を変更
        /// </summary>
        /// <param name="textBox">対象テキスト制御</param>
        /// <param name="scrollViewer">対象テキストのスクロール制御</param>
        public void ReformTextBox(TextBox textBox, ScrollViewer scrollViewer)
        {
            bool flagWrap = (settingsRef.GetSettingEval(ConfigReg.result_wrap) == "1") ? true : false;
            string strFontName = settingsRef.GetSettingEval(ConfigReg.font_name);
            string strFontSize = settingsRef.GetSettingEval(ConfigReg.font_size);
            if (flagWrap)
            {
                textBox.TextWrapping = TextWrapping.Wrap;
                scrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
            }
            else
            {
                textBox.TextWrapping = TextWrapping.NoWrap;
                scrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Auto;
            }
            ChangeTxtFontFamily(textBox, strFontName);
            int nFont;
            if (int.TryParse(strFontSize, out nFont))
            {
                textBox.FontSize = nFont;
            }
        }
        /// <summary>
        /// ウィンドウ表示／非表示切り替え
        /// </summary>
        /// <param name="col">列情報制御</param>
        /// <param name="visible">表示／非表示</param>
        public void visibilityWindow(ColumnDefinition col, bool visible)
        {
            if (visible)
            {
                col.Width = new GridLength(1, GridUnitType.Star);
            }
            else
            {
                col.Width = new GridLength(0);
            }
        }
    }
}
