//
// Copyright (c) 2026 Yobi
// Released under the MIT License
// http://opensource.org/licenses/mit-license.php
//
//
// 設定ダイアログ
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows;

namespace jlcheck_gui_w
{
    /// <summary>
    /// JlcConfigDialog.xaml の相互作用ロジック
    /// </summary>
    public partial class JlcConfigDialog : Window
    {
        /// <summary>
        /// 設定値初期化する時の種類
        /// </summary>
        enum InitType    // 設定値初期化する時の種類
        {
            None = 0,    // 初期化なし
            Original,    // 初期状態に戻す
            Load,        // XMLから読み戻す
        }
        InitType selInitType;
        JlcSettings settingsRef;
        /// <summary>
        /// コンストラクタ（AvaloniaのXAMLプレビュー用）
        /// </summary>
        public JlcConfigDialog()  // AvaloniaでXAMLプレビューするために必要
        {
            InitializeComponent();
            settingsRef = new JlcSettings();
        }
        /// <summary>
        /// コンストラクタ
        /// </summary>
        /// <param name="settings"></param>
        public JlcConfigDialog(JlcSettings settings)
        {
            InitializeComponent();
            selInitType = InitType.None;
            settingsRef = settings;
            InitTextVar(settingsRef);
        }
        /// <summary>
        /// フォント名リスト生成と現フォント検索
        /// </summary>
        /// <param name="settings"></param>
        private void InitTextFontList(JlcSettings settings)
        {
            string nameFontIn = settings.GetSettingEval(ConfigReg.font_name);
            int nSel = 0;
            cmbFontName.Items.Add("");   // 選択フォントなしを念のため入れる
            List<string> listFont = settings.getFontFamilies();
            for (int i = 0; i < listFont.Count; i++)
            {
                string font = listFont[i];
                cmbFontName.Items.Add(font);
                if (font == nameFontIn)
                {
                    nSel = i + 1;
                }
            }
            cmbFontName.SelectedIndex = nSel;
        }
        /// <summary>
        /// 設定内容を変数内容にする
        /// </summary>
        /// <param name="settings"></param>
        public void InitTextVar(JlcSettings settings)
        {
            txtWorkBase.Text = settings.GetSettingRaw(ConfigReg.dir_work_base);
            txtLogBase.Text = settings.GetSettingRaw(ConfigReg.dir_ini_inlog);
            txtEditor.Text = settings.GetSettingRaw(ConfigReg.editor);
            txtResult.Text = settings.GetSettingRaw(ConfigReg.result);
            txtOrgResult.Text = settings.GetSettingRaw(ConfigReg.org_result);
            txtFontSize.Text = settings.GetSettingRaw(ConfigReg.font_size);
            chkResultWrap.IsChecked = settings.GetSettingBool(ConfigReg.result_wrap);
            InitTextFontList(settings);
        }
        /// <summary>
        /// 設定内容を初期状態に戻す
        /// </summary>
        /// <param name="flagRead"></param>
        public void InitDataRestore(bool flagRead)
        {
            JlcSettings settingsTmp = new JlcSettings();
            settingsTmp.InitSettings(flagRead);
            InitTextVar(settingsTmp);
        }
        /// <summary>
        /// 設定内容に変数を更新
        /// </summary>
        /// <param name="settings"></param>
        public void AdaptSettings(JlcSettings settings)
        {
            if (selInitType == InitType.Original)   // 初期設定戻し
            {
                bool flagRead = false;
                settings.InitSettings(flagRead);
            }
            else if (selInitType == InitType.Load)    // 再読み込み
            {
                bool flagRead = true;
                settings.InitSettings(flagRead);
            }
            selInitType = InitType.None;
            settings.SetSetting(ConfigReg.dir_work_base, txtWorkBase.Text ?? "");
            settings.SetSetting(ConfigReg.dir_ini_inlog, txtLogBase.Text ?? "");
            settings.SetSetting(ConfigReg.editor, txtEditor.Text ?? "");
            settings.SetSetting(ConfigReg.result, txtResult.Text ?? "");
            settings.SetSetting(ConfigReg.org_result, txtOrgResult.Text ?? "");
            settings.SetSetting(ConfigReg.font_size, txtFontSize.Text ?? "");
            settings.SetSettingBool(ConfigReg.result_wrap, chkResultWrap.IsChecked);
            settings.SetSetting(ConfigReg.font_name, cmbFontName.SelectedItem?.ToString() ?? "");
        }
        /// <summary>
        /// （GUIイベント）「再読込」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Click_Reload(object sender, RoutedEventArgs e)
        {
            bool flagRead = true;
            InitDataRestore(flagRead);
            selInitType = InitType.Load;     // 再読み込み
        }
        /// <summary>
        /// （GUIイベント）「初期化」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Click_Init(object sender, RoutedEventArgs e)
        {
            bool flagRead = false;
            InitDataRestore(flagRead);
            selInitType = InitType.Original;    // 初期設定戻し
        }
        /// <summary>
        /// （GUIイベント）「OK」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void OkButton_Click(object sender, RoutedEventArgs e)
        {
            CloseDialog(true);
        }
        /// <summary>
        /// （GUIイベント）「キャンセル」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            CloseDialog(false);
        }
        /// <summary>
        /// （GUIイベント）「設定保存」ボタン
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Button_Click_Save(object sender, RoutedEventArgs e)
        {
            AdaptSettings(settingsRef);  // 現在のダイアログ内容に設定
            settingsRef.SaveSettings();  // 保存
            CloseDialog(true);
        }
        private void CloseDialog(bool flagOk)
        {
#if AVALONIA
            Close(flagOk);
#else
            DialogResult = flagOk;
            Close();
#endif

        }
    }
}