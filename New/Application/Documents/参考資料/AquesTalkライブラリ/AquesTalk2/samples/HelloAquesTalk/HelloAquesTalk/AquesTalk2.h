//////////////////////////////////////////////////////////////////////
/*!	@class	AquesTalk2

	@brief	規則音声合成エンジン AquesTalk2-Mac

  音声記号列から音声波形データをメモリ上に生成する
  出力音声波形は、8HKzサンプリング, 16bit,モノラル,WAVフォーマット


	@author	AQUEST

	@date	2009/11/28	Creation (from AuesTalk.h)
	@date	2011/02/03	_Synthe CAqTkF_Init()の戻り値をチェック
	@date	2025/004/27	AquesTalk2_Synthe_Euc,AquesTalk2_Synthe_Roman 削除
*/
//  COPYRIGHT (C) 2009 AQUEST CORP.
//////////////////////////////////////////////////////////////////////
#if !defined(_AQUESTALK2_H_)
#define _AQUESTALK2_H_
#ifdef __cplusplus
extern "C"{
#endif


/////////////////////////////////////////////
//!	音声記号列から音声波形を生成
//!	音声波形データは内部で領域確保される。
//!	音声波形データの解放は本関数の呼び出し側でAquesTalk_FreeWave()にて行う
//! @param	iSpeed [in]	発話速度 [%] 50-300 の間で指定 default:100
//!	@param	pSize [out]	生成した音声データのサイズ[byte]（エラーの場合はエラーコードが返る）
//!	@param	phontDat [in]	phontデータの先頭アドレスを指定します。デフォルトPhontを用いるときは０を指定。
//!	@return	WAVフォーマットの音声データの先頭アドレス。エラー時はNULLが返る
//! @param	koe [in]		音声記号列（SJIS NULL終端）
unsigned char * AquesTalk2_Synthe(const char *koe, int iSpeed, int *pSize, const void *phontDat);

//! @param	koe [in]		音声記号列（UTF8 NULL終端 BOMはつけられない）
unsigned char * AquesTalk2_Synthe_Utf8(const char *koe, int iSpeed, int *pSize, const void *phontDat);

//! @param	koe [in]		音声記号列（UTF16 NULL終端 BOMの有無は問わない　エンディアンは実行環境に従う）
unsigned char * AquesTalk2_Synthe_Utf16(const unsigned short *koe, int iSpeed, int *pSize, const void *phontDat);

/////////////////////////////////////////////
//!	音声データの領域を開放
//!	@param  wav[in]		AquesTalk_Synthe()で返されたアドレスを指定
void AquesTalk2_FreeWave(unsigned char *wav);

#ifdef __cplusplus
}
#endif
#endif // !defined(_AQUESTALK2_H_)
//  ----------------------------------------------------------------------
// !  Copyright AQUEST Corp. 2006- .  All Rights Reserved.                !
// !  An unpublished and CONFIDENTIAL work.  Reproduction, adaptation, or !
// !  translation without prior written permission is prohibited except   !
// !  as allowed under the copyright laws.                                !
//  ----------------------------------------------------------------------
