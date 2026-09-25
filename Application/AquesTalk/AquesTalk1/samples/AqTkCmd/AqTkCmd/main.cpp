//
//  main.cpp
//  AqTkCmd　-　AquesTalk1 Mac sample program
//
//  Usage: echo こんにちわ | ./AqTkCmd > output.wav

#include <iostream>
#include <string>
#include "AquesTalk1-mac.h"

int main(int argc, const char * argv[]) {
    AquesTalk_SetDevKey("XXX-XXX-XXX");
    AquesTalk_SetUsrKey("YYY-YYY-YYY");

    std::string koe;
    std::cin>>koe;

    int dataSize=0;
    unsigned char *wav = AquesTalk_Synthe_Utf8(koe.c_str(), 100, &dataSize);
    if(wav==0) return dataSize; // errorを返す
    std::cout.write((char*)wav, dataSize);
    return 0;
}
