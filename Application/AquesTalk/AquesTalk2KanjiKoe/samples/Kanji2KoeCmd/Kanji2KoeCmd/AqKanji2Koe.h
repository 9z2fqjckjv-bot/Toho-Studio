//////////////////////////////////////////////////////////////////////
/*!	@class	AqKanji2Koe

	@brief	AquesTalk用言語処理部 AqKanji2Koe-A Mac

  漢字かな混じりテキスト->かな音声記号列


	@date	2025/04/23	Ver.4.1.1 Apple Silicon対応
*/
//  COPYRIGHT (C) 2019 AQUEST CORP.
//////////////////////////////////////////////////////////////////////
#pragma once
#ifdef __cplusplus
extern "C"{
#endif

/////////////////////////////////////////////
//!	言語処理インスタンス生成（初期化）
//! @param	pathDic [in]		辞書のディレクトリを指定(最後に/が有っても無くても良い）
//! @param	pErr [out]		エラー時にはエラーコードが入る 正常終了時は不定値
//!	@return	インスタンスハンドル エラーの時は０が返る
void *  AqKanji2Koe_Create(const char *pathDic, int *pErr);

/////////////////////////////////////////////
//!	言語処理インスタンス生成 （初期化）その２
//!   呼び出し側で辞書データ(バイナリ)をメモリに読み込んでから指定
//!   初期化を高速化するためのメモリマップトファイルなどが使える
//! @param	pSysDic [in]		システム辞書データ先頭アドレス(必須)
//! @param	pUserDic [in]	ユーザ辞書データ先頭アドレス（使用しないときは0を指定）
//! @param	pErr [out]		エラー時にはエラーコードが入る 正常終了時は不定値
//!	@return	インスタンスハンドル エラーの時は０が返る
void *  AqKanji2Koe_Create_Ptr(const void *pSysDic, const void *pUserDic, int *pErr);

/////////////////////////////////////////////
//!	インスタンス解放
//! @param	hAqKanji2Koe [in]	AqKanji2Koe_Create()で返されたインスタンスハンドル
void   AqKanji2Koe_Release(void *hAqKanji2Koe);

/////////////////////////////////////////////
//!	言語処理 (かな音声記号列出力)
//! @param	hAqKanji2Koe [in]	AqKanji2Koe_Create()で返されたインスタンスハンドル
//! @param	kanji [in]	漢字かな混じり文テキスト（UTF8 BOM無)
//! @param	koe [out]	カナ音声記号列（UTF8 BOM無)
//! @param	nBufKoe [in]	koeのバッファサイズ[byte]
//!	@return	0:正常終了 それ以外：エラーコード
int  AqKanji2Koe_Convert(void *hAqKanji2Koe, const char *kanji, char *koe, int nBufKoe);

/////////////////////////////////////////////
//!	言語処理 (ローマ字音声記号列出力)
//! @param	hAqKanji2Koe [in]	AqKanji2Koe_Create()で返されたインスタンスハンドル
//! @param	kanji [in]	漢字かな混じり文テキスト（UTF8 BOM無)
//! @param	koe [out]	ローマ字音声記号列（UTF8 BOM無)
//! @param	nBufKoe [in]	koeのバッファサイズ[byte]
//!	@return	0:正常終了 それ以外：エラーコード
int  AqKanji2Koe_ConvRoman(void *hAqKanji2Koe, const char *kanji, char *koe, int nBufKoe);

/////////////////////////////////////////////
//!	開発ライセンスキー設定
//!	音声波形を生成する前に一度呼び出す。
//!	これにより評価版の制限がなくなる。
//!	@param  devKey [in]		開発ライセンスキーを指定
//!	@return	ライセンスキーが正しければ0、正しくなければ1が返る
//! *キーの解析を防ぐため不正なキーでも0を返す場合がある。このとき制限は解除されない。
int AqKanji2Koe_SetDevKey(const char *devKey);

#ifdef __cplusplus
}
#endif
//  ----------------------------------------------------------------------
// !  Copyright AQUEST Corp. 2006- .  All Rights Reserved.                !
// !  An unpublished and CONFIDENTIAL work.  Reproduction, adaptation, or !
// !  translation without prior written permission is prohibited except   !
// !  as allowed under the copyright laws.                                !
//  ----------------------------------------------------------------------
