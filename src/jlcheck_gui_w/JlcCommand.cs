//
// Copyright (c) 2026 Yobi
// Released under the MIT License
// http://opensource.org/licenses/mit-license.php
//
//
// 外部コマンド実行処理
//
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml.Serialization;

namespace jlcheck_gui_w
{
    /// <summary>
    /// イベント通知内容クラス
    /// </summary>
    public class NotifyEventArgs : EventArgs
    {
        public string Message { get; }

        public NotifyEventArgs(string message)
        {
            Message = message;
        }
    }
    /// <summary>
    /// コマンド実行の種類
    /// </summary>
    public enum CmdNameSelect   // コマンド実行の種類
    {
        mkenv,              // 作業フォルダ・入力データ作成
        gojls,              // join_logo_scp実行
        edit,               // 解析起動スクリプト編集
    }
    /// <summary>
    /// 外部コマンド実行処理クラス
    /// </summary>
    public class JlcCommand
    {
        public event EventHandler<NotifyEventArgs> AddLogEvent = delegate { };

        const int MaxEditable = 2;    // スクリプト編集で同時に可能とするファイル上限
        JlcSettings settingsRef;
        /// <summary>
        /// コンストラクタ
        /// </summary>
        /// <param name="settings"></param>
        public JlcCommand(JlcSettings settings)
        {
            settingsRef = settings;
        }
        //----------------------------------------------------------
        // コマンド受付
        //----------------------------------------------------------
        /// <summary>
        /// 実行コマンド受付
        /// </summary>
        /// <param name="cmdtype">実行するコマンド</param>
        /// <param name="listArg">実行に使用する引数</param>
        public void RunCommand(CmdNameSelect cmdtype, List<string> listArg)
        {
            switch (cmdtype)
            {
                case CmdNameSelect.mkenv:
                    GoMkenv(listArg);
                    break;
                case CmdNameSelect.gojls:
                    GoJls(listArg);
                    break;
                case CmdNameSelect.edit:
                    GoEditBoot(listArg);
                    break;
                default:
                    break;
            }
        }
        //----------------------------------------------------------
        // コマンド処理
        //----------------------------------------------------------
        /// <summary>
        /// 作業環境生成
        /// </summary>
        /// <param name="listLogFile">Amatsukazeログファイル名リスト</param>
        private void GoMkenv(List<string> listLogFile)
        {
            string dirBase = settingsRef.GetSettingEval(ConfigReg.dir_work_base);
            string strScr = settingsRef.GetScriptFullPath(ConfigReg.scr_mkenv);
            string strFlow = "mkenv";
            foreach (string strLogFile in listLogFile)
            {
                //--- コマンド引数生成 ---
                List<string> listIn = new List<string>();
                listIn.Add(strScr);
                listIn.Add("-flow");
                listIn.Add(strFlow);
                listIn.Add("-workbase");
                listIn.Add(dirBase);
                listIn.Add(strLogFile);
                //--- 実行文字列設定 ---
                string strCmd;
                string strArg;
                (strCmd, strArg) = MakeExecuteString(CmdNameSelect.mkenv, listIn);
                //--- 実行 ---
                ExeCmdWithLog(strCmd, strArg);
            }
        }
        /// <summary>
        /// join_logo_scp実行
        /// </summary>
        /// <param name="listGoFile">実行ファイル名リスト</param>
        private void GoJls(List<string> listGoFile)
        {
            foreach (string pathScr in listGoFile)
            {
                //--- 引数を作成 ---
                List<string> listIn = new List<string>();
                listIn.Add(pathScr);
                //--- 実行文字列設定 ---
                string strCmd;
                string strArg;
                (strCmd, strArg) = MakeExecuteString(CmdNameSelect.gojls, listIn);
                //--- 実行 ---
                ExeCmdWithLog(strCmd, strArg);
            }
        }
        /// <summary>
        /// 解析起動スクリプト参照エディタ起動
        /// </summary>
        /// <param name="listGoFile">解析するファイル名リスト</param>
        private void GoEditBoot(List<string> listGoFile)
        {
            int countExe = 0;
            foreach (string pathScr in listGoFile)
            {
                //--- 引数を作成 ---
                List<string> listIn = new List<string>();
                listIn.Add(pathScr);
                //--- 実行文字列設定 ---
                string strCmd;
                string strArg;
                (strCmd, strArg) = MakeExecuteString(CmdNameSelect.edit, listIn);
                //--- 実行 ---
                ExeCmdWithoutLog(strCmd, strArg);
                //--- 参照数制限 ---
                countExe += 1;
                if (countExe >= MaxEditable) break;
            }
        }
        //----------------------------------------------------------
        // 文字列作成
        //----------------------------------------------------------
        /// <summary>
        /// 実行するコマンドと引数を生成
        /// </summary>
        /// <param name="cmdtype">実行するコマンド</param>
        /// <param name="listArg">実行に使用する引数リスト</param>
        /// <returns>コマンド名と引数文字列</returns>
        private (string cmd, string arg) MakeExecuteString(CmdNameSelect cmdtype, List<string> listArg)
        {
            string strCmd = "";
            string strArg = "";
            (strCmd, strArg) = GetCmdName(cmdtype);  // コマンド文字列設定
            foreach (string strAdd in listArg)
            {
                strArg = ConcatArgString(strArg, strAdd);
            }
            return (strCmd, strArg);
        }
        /// <summary>
        /// 実行コマンドを設定
        /// </summary>
        /// <param name="cmdtype">実行するコマンド</param>
        /// <returns>コマンド名とコマンドに付随する引数文字列</returns>
        private (string cmd, string arg) GetCmdName(CmdNameSelect cmdtype)
        {
            string strCmd;
            string strArg;
            switch (cmdtype)
            {
                case CmdNameSelect.mkenv:
                case CmdNameSelect.gojls:
                    strCmd = settingsRef.GetSettingEval(ConfigReg.shell_cmd);
                    strArg = settingsRef.GetSettingEval(ConfigReg.shell_add);
                    break;
                case CmdNameSelect.edit:
                    strCmd = settingsRef.GetSettingEval(ConfigReg.editor);
                    strArg = "";
                    break;
                default:
                    strCmd = "";
                    strArg = "";
                    break;
            }
            return (strCmd, strArg);
        }
        /// <summary>
        /// 文字列結合
        /// </summary>
        /// <param name="strBase">元の引数</param>
        /// <param name="strAdd">追加する引数</param>
        /// <returns>追加後の引数</returns>
        private string ConcatArgString(string strBase, string strAdd)
        {
            string strDelim = (string.IsNullOrEmpty(strBase)) ? "" : " ";
            return String.Concat(strBase, strDelim, "\"", strAdd, "\"");
        }
        //----------------------------------------------------------
        // 実行処理
        //----------------------------------------------------------
        /// <summary>
        /// コンソールに文字列を追加するイベント発行
        /// </summary>
        /// <param name="strAdd"></param>
        private void AddStrConsole(string strAdd)
        {
            strAdd = FilterStringAttribute(strAdd);
            AddLogEvent?.Invoke(this, new NotifyEventArgs(strAdd));
        }
        /// <summary>
        /// powershellから出力されるテキストではない制御コードを削除
        /// </summary>
        /// <param name="strIn">出力予定の文字列</param>
        /// <returns>制御コード削除後の文字列</returns>
        private string FilterStringAttribute(string strIn)
        {
            return Regex.Replace(strIn, @"\x1b\[[0-9;]*m", "");
        }
        // ログ出力ありの実行
        private void ExeCmdWithLog(string strCmd, string strArg)
        {
            AddStrConsole(strCmd + " " + strArg);
            if (string.IsNullOrEmpty(strCmd))
            {
                AddStrConsole("実行するコマンドが見つかりませんでした（JLCheck設定）");
                return;
            }
            try
            {
                var p = new Process();
                p.StartInfo.FileName = strCmd;
                p.StartInfo.Arguments = strArg;
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.CreateNoWindow = true;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.RedirectStandardError = true;
                p.StartInfo.StandardOutputEncoding = Encoding.UTF8;
                p.Start();
                p.OutputDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        AddStrConsole(e.Data);
                    }
                };
                p.ErrorDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        AddStrConsole(e.Data);
                    }
                };
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                p.WaitForExit();
            }
            catch (Exception ex)
            {
                AddStrConsole(ex.ToString());
                AddStrConsole($"コマンド({strCmd})実行中にエラー : 引数({strArg})");
            }
        }
        /// <summary>
        /// ログ出力なしの実行
        /// </summary>
        /// <param name="strCmd">コマンド文字列</param>
        /// <param name="strArg">引数文字列</param>
        private void ExeCmdWithoutLog(string strCmd, string strArg)
        {
            AddStrConsole(strCmd + " " + strArg);  // 実行文字列のみログ出力
            if (string.IsNullOrEmpty(strCmd))
            {
                AddStrConsole("実行するコマンドが見つかりませんでした（JLCheck設定）");
                return;
            }
            try
            {
                var p = new Process();
                p.StartInfo.FileName = strCmd;
                p.StartInfo.Arguments = strArg;
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.CreateNoWindow = true;
                p.Start();
            }
            catch (Exception ex)
            {
                AddStrConsole(ex.ToString());
                AddStrConsole($"コマンド({strCmd})実行中にエラー : 引数({strArg})");
            }
        }
    }
}
