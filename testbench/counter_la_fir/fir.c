#include "fir.h"

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
	for(int i=0; i<11; i++){
		inputbuffer[i] = 0;
		outputsignal[i] = 0;
		
	}
	for(int i=0; i<N; i++){
		inputsignal[i] = i;
	}
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	//write down your fir
	int arr[11];
	for(int i=0; i<N; i++){
		for(int j=10; j>0; j--){
			inputbuffer[j] = inputbuffer[j-1];
		}
		inputbuffer[0] = inputsignal[i];
		arr[0] = inputbuffer[0] * taps[0];
		arr[1] = inputbuffer[1] * taps[1];
		arr[2] = inputbuffer[2] * taps[2];
		arr[3] = inputbuffer[3] * taps[3];
		arr[4] = inputbuffer[4] * taps[4];
		arr[5] = inputbuffer[5] * taps[5];
		arr[6] = inputbuffer[6] * taps[6];
		arr[7] = inputbuffer[7] * taps[7];
		arr[8] = inputbuffer[8] * taps[8];
		arr[9] = inputbuffer[9] * taps[9];
		arr[10] = inputbuffer[10] * taps[10];
		outputsignal[i] = arr[0] + arr[1] + arr[2] + arr[3] + arr[4] + arr[5] + arr[6] + arr[7] + arr[8] + arr[9] + arr[10];
	}
	return outputsignal;
}
		
