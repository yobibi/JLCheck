//
// Copyright (c) 2026 Yobi
// Released under the MIT License
// http://opensource.org/licenses/mit-license.php
//
//
// ポップアップダイアログ
// WPF/Avalonia UI共通のインターフェースで使用可能
//
// Avalonia UIで使う時は AVALONIA を定義しておく
// （例）.csprojファイルの <PropertyGroup>内に下記定義を追加する
//       <DefineConstants>$(DefineConstants);AVALONIA</DefineConstants>
//
// OpenFileAsync
// 機能：ファイル名フルパスをダイアログで選択して返す
// 関数：static async Task<string> OpenFile(FileDialogOptionsInfo optDialog)
// 引数：説明後述
// 返値：終了を待って選択文字列を渡す。キャンセル時は空文字列
//
// OpenFolderAsync
// 機能：フォルダ名フルパスをダイアログで選択して返す
// 関数：static async Task<string> OpenFolder(FileDialogOptionsInfo optDialog)
// 引数：説明後述
//       フィルター関連の設定は無効
// 返値：終了を待って選択文字列を渡す。キャンセル時は空文字列
//
// OpenModalDialogAsync
// 機能：モーダルダイアログ設定を行う
// 関数：static async Task<bool> OpenModalDialog(Window dlg, Window parent)
// 引数：dlg     実行するダイアログクラス
//       parent  親ウィンドウ
// 返値：終了を待って結果を渡す。OKで戻る時はtrue、結果を破棄して戻る時はfalse
//
//（共通）
// 使用するソースでusing宣言する
//   using UserDialogSet;
// staticのため、FileDialogクラス生成は不要
// 終了を待つため、async宣言した関数からawait待ちを入れて呼び出す
//
// （使用する引数）
// FileDialogOptionsInfo
// ファイルダイアログを使用する時はこのクラスに情報を入れて渡す
// - クラス作成は親ウィンドウ情報が取得できる所で行う
//  （例）FileDialogOptionsInfo optDialog = new FileDialogOptionsInfo(this);
// - titleは設定しなければデフォルト設定になる
// - iniDirは設定しなければデフォルト設定になる
// - withAllFilterは、フィルター設定してALLも別途追加したい時にtrueを入れる
// - filterは表示コメントとパターンをセットでListに追加していく
//  （例）optDialog.filter.Add(("logファイル(*.log)", "*.log"));
// - filterパターンで複数拡張子は間にセミコロンを入れる
//  （例）optDialog.filter.Add(("textファイル(*.log *.txt)", "*.log;*.txt"));
//
//使用例（ファイル選択）
//  FileDialogOptionsInfo optDialog = new FileDialogOptionsInfo(this);
//  optDialog.title = "表示タイトル";
//  optDialog.iniDir = folderName;
//  optDialog.filter.Add(("logファイル(*.log)", "*.log"));
//  optDialog.filter.Add(("textファイル(*.log *.txt)", "*.log;*.txt"));
//  optDialog.withAllFilter = true;
//  string pathSel = await FileDialog.OpenFileAsync(optDialog);
//  if (!String.IsNullOrWhiteSpace(pathSel)) {
//    textbox.Text = pathSel;
//  }
//
//使用例（モーダルダイアログ）
//  MyDialog dialog = new MyDialog(myData)
//  if (await FileDialog.OpenModalDialogAsync(dialog, this))
//    dialog.setData(myData);
//  }
//

using Avalonia;
using Avalonia.Controls;
using Avalonia.Platform.Storage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace UserDialogSet
{
    /// <summary>
    /// ファイルダイアログを使用する時はこのクラスに情報を入れて渡す
    /// </summary>
    public class FileDialogOptionsInfo
    {
        public string title;        // ダイアログのタイトル
        public string iniDir;       // ディレクトリ位置初期設定
        public bool withAllFilter;  // trueの時、*.*をフィルターに追加
        public List<(string Msg, string Pat)> filter;  // フィルター設定
        public Window parent;       // ダイアログの親ウィンドウ
        public FileDialogOptionsInfo(Window parent)
        {
            this.parent = parent;
            title = "";
            iniDir = "";
            withAllFilter = false;
            filter = new List<(string Msg, string Pat)>();
        }
        //--- フィルター設定を取得 ---
        public List<(string Msg, string Pat)> GetListFilter()
        {
            if (filter.Count > 0 && !withAllFilter)
            {
                return filter;
            }
            (string Msg, string Pat) iniVal = ("all(*.*)", "*.*");
            List<(string Msg, string Pat)> tmpFilter = filter;
            tmpFilter.Add(iniVal);
            return tmpFilter;
        }
    }
    /// <summary>
    /// ポップアップダイアログ用クラス
    /// </summary>
    public class FileDialog
    {
#if AVALONIA
        /// <summary>
        /// ファイル選択
        /// </summary>
        /// <param name="optDialog"></param>
        /// <returns>選択されたファイル名</returns>
        public static async Task<string> OpenFileAsync(FileDialogOptionsInfo optDialog)
        {
            List<FilePickerFileType> picker = new List<FilePickerFileType>();
            foreach ((string Msg, string Pat) in optDialog.GetListFilter())
            {
                FilePickerFileType onepic = new FilePickerFileType(Msg)
                {
                    Patterns = Pat.Split(";")
                };
                picker.Add(onepic);
            }
            var topLevel = TopLevel.GetTopLevel(optDialog.parent);
            if (topLevel == null) return "";
            var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
            {
                Title = optDialog.title,
                AllowMultiple = false,
                SuggestedStartLocation = await topLevel.StorageProvider.TryGetFolderFromPathAsync(optDialog.iniDir),
                FileTypeFilter = picker,
            });
            if (files.Count >= 1)
            {
                var file = files.First();
                string filePath = Uri.UnescapeDataString(file.Path.AbsolutePath);
                return filePath;
            }
            return "";
        }
        /// <summary>
        /// フォルダ選択
        /// </summary>
        /// <param name="optDialog">入力オプション</param>
        /// <returns>選択されたフォルダ名</returns>
        public static async Task<string> OpenFolderAsync(FileDialogOptionsInfo optDialog)
        {
            var topLevel = TopLevel.GetTopLevel(optDialog.parent);
            if (topLevel == null) return "";
            var files = await topLevel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                Title = optDialog.title,
                AllowMultiple = false,
                SuggestedStartLocation = await topLevel.StorageProvider.TryGetFolderFromPathAsync(optDialog.iniDir),
            });
            if (files.Count >= 1)
            {
                var file = files.First();
                string filePath = Uri.UnescapeDataString(file.Path.AbsolutePath);
                return filePath;
            }
            return "";
        }
        /// <summary>
        /// Modalダイアログ
        /// </summary>
        /// <param name="dlg">ダイアログクラス</param>
        /// <param name="parent">親ウィンドウ</param>
        /// <returns></returns>
        public static async Task<bool> OpenModalDialogAsync(Window dlg, Window parent)
        {
            return await dlg.ShowDialog<bool>(parent);
        }
#else
        // WPFはasyncにする必要ないが、場合分けが面倒なのでasync化してI/Fを合わせている
        /// <summary>
        /// ファイル選択
        /// </summary>
        /// <param name="optDialog">入力オプション</param>
        /// <returns>選択されたファイル名</returns>
        public static async Task<string> OpenFileAsync(FileDialogOptionsInfo optDialog)
        {
            string filter = "";
            string delim = "";
            foreach ((string Msg, string Pat) in optDialog.GetListFilter())
            {
                filter += delim;
                filter += Msg;
                delim = "|";
                filter += delim;
                filter += Pat;
            }
            OpenFileDialog ofDialog = new OpenFileDialog();
            ofDialog.Title = optDialog.title;
            ofDialog.Filter = filter;
            if (!String.IsNullOrWhiteSpace(optDialog.iniDir))
            {
                ofDialog.InitialDirectory = optDialog.iniDir;
            }
            string result = "";
            if (ofDialog.ShowDialog() == true)
            {
                result = ofDialog.FileName;
            }
            return await Task.Run(() => { return result; });
        }
        /// <summary>
        /// フォルダ選択
        /// </summary>
        /// <param name="optDialog">入力オプション</param>
        /// <returns>選択されたフォルダ名</returns>
        public static async Task<string> OpenFolderAsync(FileDialogOptionsInfo optDialog)
        {
            OpenFileDialog ofDialog = new OpenFileDialog();
            ofDialog.Title = optDialog.title;
            ofDialog.FileName = "SelectFolder";
            ofDialog.Filter = "Folder|.";
            if (!String.IsNullOrWhiteSpace(optDialog.iniDir))
            {
                ofDialog.InitialDirectory = optDialog.iniDir;
            }
            ofDialog.CheckFileExists = false;
            string result = "";
            if (ofDialog.ShowDialog() == true)
            {
                result = System.IO.Path.GetDirectoryName(ofDialog.FileName);
            }
            return await Task.Run(() => { return result; });
        }
        /// <summary>
        /// Modalダイアログ
        /// </summary>
        /// <param name="dlg">ダイアログクラス</param>
        /// <param name="parent">親ウィンドウ</param>
        /// <returns></returns>
        public static async Task<bool> OpenModalDialogAsync(Window dlg, Window parent)
        {
            //Window parent = (Window) VisualTreeHelper.GetParent(dlg);
            dlg.Owner = parent;
            bool result = dlg.ShowDialog() ?? false;
            return await Task.Run(() => { return result; });
        }
#endif
    }
}
