declare name "Compressor";
declare author "Mayank Sanganeria";
declare version "0.1";


SR = fconstant(int fSamplingFreq, <math.h>);

// Controls




//Level estimator


leaky(x,a) = +((exp(-1/(SR*t)))*abs(x))~(1-a)*_';
level = leaky(_,0.01);

//Gain computer
gain = select2((level>0.1),1,0.1);


process = gain*_;