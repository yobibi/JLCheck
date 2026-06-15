//
// Copyright (c) 2026 Yobi
// Released under the MIT License
// http://opensource.org/licenses/mit-license.php
//
//
// メインウィンドウ
//
using jlcheck_gui_w.Properties;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

using UserDialogSet;

namespace jlcheck_gui_w
{
    /// <summary>
    /// MainWindow.xaml の相互作用ロジック
    /// </summary>
    public partial class MainWindow : Window
    {
        //----------------------------------------------------------
        // 初期化
        //----------------------------------------------------------
        JlcSettings settings;          // 設定保管
        JlcFuncData funcData;          // データ作成関数
        /// <summary>
        /// コンストラクタ
        /// </summary>
        public MainWindow()
        {
            InitializeComponent();
            settings = new JlcSettings();
            funcData = new JlcFuncData(settings, this);
            PopSettingsLog();  // 初期設定中に出た設定クラスからのエラーログ取得
            AddEventInitial();
            InitDragDrop();
            ReformDispTextBox();
            chkDispLog.IsChecked = true;   // 初期はログ表示
            UpdataDispCheckBox();
        }
        /// <summary>
        /// XAMLに追加の処理
        /// </summary>
        private void AddEventInitial()
        {
#if AVALONIA
#else
            chkDispResult.Unchecked += Button_Checked_chkDispResult;
            chkDispOriginal.Unchecked += Button_Checked_chkDispOriginal;
            chkDispLog.Unchecked += Button_Checked_chkDispLog;
#endif
        }
        //----------------------------------------------------------
        // Drag & drop処理
        // [注釈] 現時点AVALONIAでこの処理はWindowsでは動作するがLinuxでは動作しない
        //----------------------------------------------------------
        // TextBoxにファイル名をDrag&drop
#if AVALONIA
        /// <summary>
        /// Drag & drop初期化
        /// </summary>
        private void InitDragDrop()
        {
            EnableDragDrop(brdPathAmtLog);
            EnableDragDrop(brdPathDirWork);
        }
        /// <summary>
        /// 対象TextBox枠のDrag & dropを有効化
        /// </summary>
        /// <param name="brd">対象テキスト枠制御</param>
        private void EnableDragDrop(Border brd)
        {
            DragDrop.SetAllowDrop(brd, true);
            DragDrop.AddDragOverHandler(brd, OnDragOver);
            DragDrop.AddDropHandler(brd, OnDrop);
        }
        /// <summary>
        /// Drag時に発生するイベント
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void OnDragOver(object? sender, DragEventArgs e)
        {
            e.DragEffects = e.DataTransfer.Formats.Contains(DataFormat.File) ? DragDropEffects.Copy : DragDropEffects.None;
        }
        /// <summary>
        /// Drop時に発生するイベント
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void OnDrop(object? sender, DragEventArgs e)
        {
            if (e.DataTransfer.TryGetFiles() is { } files)
            {
                List<string> listPath = new List<string>();
                foreach (var file in files) {
                    listPath.Add(file.Path.LocalPath);
                }
                if (listPath.Count > 0 && sender != null)
                {
                    Border bd = (Border)sender;
                    if (bd != null)
                    {
                        string bdname = bd.Name ?? "";
                        string txtname = bdname.Replace("brd", "txt");
                        OnDrop_MainAction(txtname, listPath);
                    }
                }
            }
        }
#else
        /// <summary>
        /// Drag & drop初期化
        /// </summary>
        private void InitDragDrop()
        {
            EnableDragDrop(txtPathAmtLog);
            EnableDragDrop(txtPathDirWork);
        }
        /// <summary>
        /// 対象TextBoxのDrag & dropを有効化
        /// </summary>
        /// <param name="textBox">対象テキスト制御</param>
        private void EnableDragDrop(TextBox textBox)
        {
            textBox.AllowDrop = true;
            textBox.PreviewDragOver += (s, e) =>
            {
                e.Effects = (e.Data.GetDataPresent(DataFormats.FileDrop)) ? DragDropEffects.Copy : e.Effects = DragDropEffects.None;
                e.Handled = true;
            };
            textBox.PreviewDrop += (s, e) =>
            {
                if (e.Data.GetDataPresent(DataFormats.FileDrop))
                {
                    List<string> listPath = new List<string>();
                    string[] paths = ((string[])e.Data.GetData(DataFormats.FileDrop));
                    listPath = paths.ToList();
                    if (listPath.Count > 0)
                    {
                        TextBox tb = (TextBox)s;
                        OnDrop_MainAction(tb.Name, listPath);
                    }
                }
            };
        }
#endif
        /// <summary>
        /// Drop時の個別処理
        /// </summary>
        /// <param name="txtName">ドロップ先テキスト制御</param>
        /// <param name="listPath">ドロップ先に渡す文字列リスト</param>
        private void OnDrop_MainAction(string txtName, List<string> listPath)
        {
            string pathIn = listPath[0];
            switch (txtName)
            {
                case "txtPathAmtLog":
                    txtPathAmtLog.Text = pathIn;
                    break;
                case "txtPathDirWork":
                    if (!Directory.Exists(pathIn))
                    {
                        // 拡張子が.logの場合はDrop場所間違いとして無効化
                        if (System.IO.Path.GetExtension(pathIn.ToLower()) == ".log") pathIn = "";
                        else
                        {
                            pathIn = System.IO.Path.GetDirectoryName(pathIn) ?? "";
                            if (!Directory.Exists(pathIn)) pathIn = "";
                        }
                    }
                    txtPathDirWork.Text = pathIn;
                    break;
            }
        }
        //----------------------------------------------------------
        // コマンド実行と他クラスからの文字列受信
        //----------------------------------------------------------
        /// <summary>
        /// ボタンによるコマンド実行
        /// </summary>
        /// <param name="btnSel">実行中無効にするボタン制御</param>
        /// <param name="cmdType">実行するコマンド</param>
        /// <param name="listArg">実行に使用する引数</param>
        /// <param name="updateResult">結果テキストを更新する場合はtrue</param>
        /// <returns></returns>
        private async Task ExecuteByButtonAsync(Button btnSel, CmdNameSelect cmdType, List<string> listArg, bool updateResult = false)
        {
            btnSel.IsEnabled = false;
            bool retEnable = await Task.Run(() =>
            {
                ExecuteCommand(cmdType, listArg);
                //System.Threading.Thread.Sleep(3000);
                if (updateResult)
                {
                    WriteDispTextResult();
                }
                return true;
            });
            btnSel.IsEnabled = retEnable;
        }
        /// <summary>
        /// コマンド実行
        /// </summary>
        /// <param name="cmdType">実行するコマンド</param>
        /// <param name="listArg">実行に使用する引数リスト</param>
        private void ExecuteCommand(CmdNameSelect cmdType, List<string> listArg)
        {
            JlcCommand cmdObj = new JlcCommand(settings);
            cmdObj.AddLogEvent += OnAddLog;
            cmdObj.RunCommand(cmdType, listArg);
            cmdObj.AddLogEvent -= OnAddLog;
        }
        /// <summary>
        /// 別クラスからのログ受信イベント
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
#if AVALONIA
        private void OnAddLog(object? sender, NotifyEventArgs e)
#else   // .NET Frameworkの制約
        private void OnAddLog(object sender, NotifyEventArgs e)
#endif
        {
            WriteConsoleLine(e.Message);
        }
        /// <summary>
        /// 設定クラスで発生したログを取得
        /// </summary>
        private void PopSettingsLog()
        {
            WriteConsoleLine(settings.PopSettingsLog());
        }
        //----------------------------------------------------------
        // テキスト表示内容作成
        //----------------------------------------------------------
        /// <summary>
        /// 1行文字列をコンソールログ表示
        /// </summary>
        /// <param name="strLine">表示する文字列</param>
        private void WriteConsoleLine(string strLine)
        {
            Dispatcher.Invoke(() =>
            {
                txtDispLog.Text += strLine + Environment.NewLine;
                sbDispLog.ScrollToEnd();
            });
        }
        /// <summary>
        /// 結果欄の文字列作成
        /// </summary>
        private void WriteDispTextResult()
        {
            Dispatcher.Invoke(() =>
            {
                funcData.WriteTextDispResult(txtDispResult, txtPathDirWork.Text ?? "");
                funcData.WriteTextDispOriginal(txtDispOriginal, txtPathDirWork.Text ?? "");
            });
        }
        //----------------------------------------------------------
        // GUI処理で行う共通処理
        //----------------------------------------------------------
        /// <summary>
        /// 入力用テキストボックスのハイライト解除
        /// </summary>
        private void ClearTxtAllBackColor()
        {
            funcData.ChangeTxtBackColor(txtPathAmtLog, MsgColorSelect.None);
            funcData.ChangeTxtBackColor(txtPathDirWork, MsgColorSelect.None);
        }
        /// <summary>
        /// テキストボックスの書式変更
        /// </summary>
        private void ReformDispTextBox()
        {
            funcData.ReformTextBox(txtDispResult, sbDispResult);
            funcData.ReformTextBox(txtDispOriginal, sbDispOriginal);
            funcData.ReformTextBox(txtDispLog, sbDispLog);
        }
        /// <summary>
        /// チェックボックス状態から表示／非表示切り替え
        /// </summary>
        private void UpdataDispCheckBox()
        {
            bool chkResult = chkDispResult.IsChecked ?? false;
            bool chkOriginal = chkDispOriginal.IsChecked ?? false;
            bool chkLog = chkDispLog.IsChecked ?? false;
            if (!(chkResult || chkOriginal || chkLog))
            {
                chkLog = true;
            }
            funcData.visibilityWindow(grdDispLabel.ColumnDefinitions[0], chkResult);
            funcData.visibilityWindow(grdDispLabel.ColumnDefinitions[1], chkOriginal);
            funcData.visibilityWindow(grdDispLabel.ColumnDefinitions[2], chkLog);
            funcData.visibilityWindow(grdDispText.ColumnDefinitions[0], chkResult);
            funcData.visibilityWindow(grdDispText.ColumnDefinitions[1], chkOriginal);
            funcData.visibilityWindow(grdDispText.ColumnDefinitions[2], chkLog);
        }
        /// <summary>
        /// 入力ログが指定されているか確認
        /// </summary>
        /// <param name="pathLog">Amatsukazeログファイルパス</param>
        /// <returns></returns>
        private bool CheckAmtLogInput(string pathLog)
        {
            if (string.IsNullOrWhiteSpace(pathLog))
            {
                funcData.ChangeTxtBackColor(txtPathAmtLog, MsgColorSelect.NoData);
                WriteConsoleLine("Amatsukazeログ（入力データ）を指定してください");
                return false;
            }
            ClearTxtAllBackColor();
            return true;
        }
        /// <summary>
        /// 作業フォルダ取得（ワイルドカードで複数可能）の対象ファイルリスト取得
        /// </summary>
        /// <param name="nameTarget">ベース作業フォルダ後の個別フォルダ名</param>
        /// <returns></returns>
        private List<string> GetMatchPathFromWorkWithCheck(string nameTarget)
        {
            List<string> listFile = new List<string>();
            string dirWork = txtPathDirWork.Text ?? "";
            if (string.IsNullOrWhiteSpace(dirWork))
            {
                funcData.ChangeTxtBackColor(txtPathDirWork, MsgColorSelect.NoData);
                WriteConsoleLine("CM解析作業フォルダを指定してください");
                return listFile;
            }
            //--- 実行に必要なファイル名生成 ---
            listFile = funcData.GetListMatchPath(dirWork, nameTarget);
            if (listFile.Count == 0)
            {
                funcData.ChangeTxtBackColor(txtPathDirWork, MsgColorSelect.WrongData);
                WriteConsoleLine($"CM解析作業フォルダの対象ファイル({nameTarget})が見つかりません");
                return listFile;
            }
            ClearTxtAllBackColor();
            return listFile;
        }
        //----------------------------------------------------------
        // GUI処理
        //----------------------------------------------------------
        /// <summary>
        /// （GUIイベント）「入力ログ選択」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private async void Button_Click_PathAmtLog(object sender, RoutedEventArgs e)
        {
            ClearTxtAllBackColor();
            await funcData.SelectPathAmtLogByDialogAsync(txtPathAmtLog);
        }
        /// <summary>
        /// （GUIイベント）作業フォルダ・入力データ作成」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private async void Button_Click_ExeMakeEnv(object sender, RoutedEventArgs e)
        {
            string pathLog = txtPathAmtLog.Text ?? "";
            if (!CheckAmtLogInput(pathLog)) return;
            List<string> listPath = new List<string>();
            listPath.Add(pathLog);
            txtPathDirWork.Text = settings.GenerateWorkDirName(pathLog);
            await ExecuteByButtonAsync(btnMakeEnv, CmdNameSelect.mkenv, listPath);
        }
        /// <summary>
        /// （GUIイベント）「既存作業フォルダ指定」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private async void Button_Click_PathDirWork(object sender, RoutedEventArgs e)
        {
            ClearTxtAllBackColor();
            await funcData.SelectPathDirWorkByDialogAsync(txtPathDirWork);
        }
        /// <summary>
        /// （GUIイベント）「CM解析実行」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private async void Button_Click_ExeBoot(object sender, RoutedEventArgs e)
        {
            string nameGo = settings.GetSettingEval(ConfigReg.scr_gojls);
            List<string> listFile = GetMatchPathFromWorkWithCheck(nameGo);
            if (listFile.Count == 0) return;
            bool updateResult = true;
            await ExecuteByButtonAsync(btnExeCm, CmdNameSelect.gojls, listFile, updateResult);
        }
        /// <summary>
        /// （GUIイベント）「解析起動スクリプト参照・修正」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Click_EditBoot(object sender, RoutedEventArgs e)
        {
            string nameGo = settings.GetSettingEval(ConfigReg.edit_gojls);
            List<string> listFile = GetMatchPathFromWorkWithCheck(nameGo);
            if (listFile.Count == 0) return;
            ExecuteCommand(CmdNameSelect.edit, listFile);
        }
        /// <summary>
        /// （GUIイベント）「CM解析結果」チェック
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Checked_chkDispResult(object sender, RoutedEventArgs e)
        {
            UpdataDispCheckBox();
        }
        /// <summary>
        /// （GUIイベント）「入力ログ時点の結果」チェック
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Checked_chkDispOriginal(object sender, RoutedEventArgs e)
        {
            UpdataDispCheckBox();
        }
        /// <summary>
        /// （GUIイベント）「実行中のログ」チェック
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Checked_chkDispLog(object sender, RoutedEventArgs e)
        {
            UpdataDispCheckBox();
        }
        /// <summary>
        /// （GUIイベント）「内容更新」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Click_btnDispUpdate(object sender, RoutedEventArgs e)
        {
            WriteDispTextResult();
        }
        /// <summary>
        /// （GUIイベント）「設定」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private async void Button_Click_Settings(object sender, RoutedEventArgs e)
        {
            ClearTxtAllBackColor();
            JlcConfigDialog dialog = new JlcConfigDialog(settings);
            if (await FileDialog.OpenModalDialogAsync(dialog, this))
            {
                dialog.AdaptSettings(settings);
                ReformDispTextBox();
            }
        }
    }
}
