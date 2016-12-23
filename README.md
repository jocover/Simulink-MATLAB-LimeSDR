#LimeSDR Matlab & Simulink interface

```
device = limeSDR();
device.rx0.frequency = 100.00e6;
device.tx0.frequency = 200.00e6;
```

Before starting, run `help limeSDR.build_thunk` to view instructions on how to have MATLAB build a Thunk file to use in conjunction with libLimeSuite.

For more information, use the MATLAB `help limeSDR` and `doc limeSDR` commands on the files in this directory

##### Simulink support

add **MATLAB System block** and choose limeSDR_Simulink.m file


