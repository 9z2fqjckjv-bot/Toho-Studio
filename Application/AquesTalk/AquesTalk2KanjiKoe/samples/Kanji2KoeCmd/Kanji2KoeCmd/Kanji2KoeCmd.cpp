/*-------------------------------------------------------------
	Kanji2KoeCmd - かな漢字混じりテキストを音声記号列に変換

	$ Kanji2KoeCmd (dic_dir) < in.txt > out.koe


	■実行時の配置
	
		|- Kanji2KoeCmd
		|- aq_dic/		辞書フォルダ(aq_dic)を同じディレクトリに配置
			|- aqdic.bin 
			|- aq_user.dic (ユーザ辞書:任意)
			|- CREDITS

	■実行
	$ echo 音声合成テスト | ./Kanji2KoeCmd 
  

-------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>		// setlocale()
#include "AqKanji2Koe.h"

#define	NSTR	4096

char * GetPathDic(const char *pathModule);

int main(int ac, char **av)
{
	int iret;
	char kanji[NSTR];
	char koe[NSTR];
	void *hAqKanji2Koe;

	iret = AqKanji2Koe_SetDevKey("XXX-XXX-XXX");
	if(ac==1){
		char *pPathDic  = GetPathDic(av[0]);
		hAqKanji2Koe = AqKanji2Koe_Create(pPathDic, &iret);
		free(pPathDic);
	}
	else {
		hAqKanji2Koe = AqKanji2Koe_Create(av[1], &iret);
	}
		
	if(hAqKanji2Koe==0){
		fprintf(stderr, "ERR: can not initialize Dictionary(%d)\n", iret);
		fprintf(stderr, "USAGE: $ Kanji2KoeCmd (dic_dir) < in.txt > out.koe\n");
		return iret;
	}

	int i;
	for(i=0; ; i++){
		if(fgets(kanji, NSTR, stdin)==0) break;
		iret = AqKanji2Koe_Convert(hAqKanji2Koe, kanji, koe, NSTR);
		if(iret!=0) {
			fprintf(stderr, "ERR: AqKanji2Koe_Convert()=%d\n", iret);
			break;
		}
		fprintf(stdout, "%s\n", koe);
	}

	AqKanji2Koe_Release(hAqKanji2Koe);
	return 0;
}

char * GetPathDic(const char *pathModule)
{
	char *p = strrchr((char*)pathModule, '/');
	if(p==NULL){
		return strdup("./aq_dic");
	}
	char *path = (char*)malloc(strlen(pathModule)+strlen("/aq_dic")+1);
	strncpy(path, pathModule, p-pathModule);
	strcpy(path+(p-pathModule), "/aq_dic");
	return path;
}

