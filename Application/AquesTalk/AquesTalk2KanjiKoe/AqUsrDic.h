//////////////////////////////////////////////////////////////////////
/*!	@class	AqUsrDic

	@brief	AqKanji2Koe-A Mac ユーザ辞書ライブラリ

	【ディレクトリ構成】
		<aq_dic>
			|- aqdic.bin	システム辞書
			|- aq_user.dic	ユーザ辞書

	【注意】
	 ユーザ辞書はシステム辞書に依存するため、
	 異なるシステム辞書との組み合わせは正常動作しない。

	@date	2025/04/25	Ver.4.1.1 Apple Silicon対応
*/
//  COPYRIGHT (C) 2019 AQUEST CORP.
//////////////////////////////////////////////////////////////////////
#pragma once
#ifdef __cplusplus
extern "C"{
#endif

//////////////////////////////////////////////////////////////
//	CSV辞書からユーザ辞書(aq_usr.dic)を生成(上書)
//	aq_user.dicと同じディレクトリにシステム辞書(aqdic.bin)があること
//
//	pathUserDic: ユーザ辞書(aq_user.dic)ファイルのパス
//	pathDicCsv:	CSV辞書ファイルのパス
//	return: 0：正常終了	それ以外：エラー
int AqUsrDic_Import(const char *pathUserDic, const char *pathDicCsv);

//////////////////////////////////////////////////////////////
//	ユーザ辞書(aq_usr.dic)からCSV辞書を生成
//	aq_user.dicと同じディレクトリにシステム辞書(aqdic.bin)があること
//
//	pathUserDic: ユーザ辞書(aq_user.dic)ファイルのパス
//	pathDicCsv:	CSV辞書ファイルのパス
//	return: 0：正常終了	それ以外：エラー
int AqUsrDic_Export(const char *pathUserDic, const char *pathDicCsv);

//////////////////////////////////////////////////////////////
//	書式のチェック
//	CSV辞書に見出し語を追加・修正するとき、ユーザ辞書の生成前に
//	読み記号列の書式などをチェック
//
//	surface: 見出し語文字列(UTF8)
//	yomi:	よみ記号列（アクセント付き発音記号列 UTF8）
//	posCode:	品詞コード（下記参照）
//	return: 0：チェックOK	それ以外：エラー
int AqUsrDic_Check(const char *surface, const char *yomi, int posCode);

//////////////////////////////////////////////////////////////
//	最後のエラーの詳細メッセージを返す
//	戻り値：エラーメッセージ（UTF8, NULL終端)
const char * AqUsrDic_GetLastError();

/*--------------------------
品詞コード(posCode)：品詞名
 0:名詞
 1:名詞(サ変)
 2:人名
 3:人名(姓)
 4:人名(名)
 5:固有名詞
 6:固有名詞(組織)
 7:固有名詞(地域)
 8:固有名詞(国)
 9:代名詞
10:代名詞(縮約)
11:名詞(副詞可能)
12:名詞(接続詞的)
13:名詞(形容動詞語幹)
14:名詞(ナイ形容詞語幹)
15:形容詞
16:副詞
17:副詞(助詞類接続)
18:接頭詞(名詞接続)
19:接頭詞(動詞接続)
20:接頭詞(数接続)
21:接頭詞(形容詞接続)
22:接続詞
23:連体詞
24:記号
25:記号(アルファベット)
26:感動詞
27:間投詞
--------------------------*/

#ifdef __cplusplus
}
#endif
//  ----------------------------------------------------------------------
// !  Copyright AQUEST Corp. 2017- .  All Rights Reserved.                !
// !  An unpublished and CONFIDENTIAL work.  Reproduction, adaptation, or !
// !  translation without prior written permission is prohibited except   !
// !  as allowed under the copyright laws.                                !
//  ----------------------------------------------------------------------
