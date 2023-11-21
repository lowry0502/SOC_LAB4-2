#ifndef __FIR_H__
#define __FIR_H__

#define N 64

int taps[11] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int inputbuffer[11] = {0};
int inputsignal[N] = {0}; // = {1,2,3,4,5,6,7,8,9,10,11};
int outputsignal[N] = {0};
#endif
