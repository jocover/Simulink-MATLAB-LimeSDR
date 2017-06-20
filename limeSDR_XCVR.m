%
% Copyright (c) 2017 JiangWei
% Copyright (c) 2015 Nuand LLC
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
%
classdef limeSDR_XCVR < handle
    
    properties(Dependent = true)
        samplerate      % Samplerate. Must be within 160 kHz and 40 MHz. A 2-3 MHz minimum is suggested unless external filters are being used.
        frequency       % Frequency. Must be within [237.5 MHz, 3.8 GHz] when no XB-200 is attached, or [0 GHz, 3.8 GHz] when an XB-200 is attached.
        bandwidth       % LPF bandwidth seting. This is rounded to the nearest of the available discrete settings. It is recommended to set this and read back the actual value.
        antenna
        gain
        channal
    end
    
    properties(SetAccess = private)
        running         % Denotes whether or not the module is enabled to stream samples.
        timestamp       % Provides a coarse readback of the timestamp counter.
    end
    
    properties (Access = private)
        
        
        
    end
    
    properties(SetAccess = immutable, Hidden=true)
        limesdr         % Associated limeSDR device handle
        isTx            % Module specifier (as a libLimeSuite enum)
        chan
    end
    
    methods
        
        function set.samplerate(obj, val)
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetSampleRate', obj.limesdr.device,val,2));
        end
        
        function samplerate_val = get.samplerate(obj)
            host_Hz=libpointer('doublePtr',0);
            rf_Hz=libpointer('doublePtr',0);
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_GetSampleRate', obj.limesdr.device,obj.isTx,obj.chan,host_Hz,rf_Hz));
            samplerate_val=host_Hz.value;
        end
        
        function set.frequency(obj, val)
            %  limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetLOFrequency', obj.limesdr.device,obj.isTx,obj.chan,val));
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetLOFrequency', obj.limesdr.device,obj.isTx,0,val));
        end
        
        function freq_val = get.frequency(obj)
            freq_hz=libpointer('doublePtr',0);
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_GetLOFrequency', obj.limesdr.device,obj.isTx,obj.chan,freq_hz));
            freq_val=freq_hz.value;
        end
        
        function set.bandwidth(obj, val)
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetLPFBW', obj.limesdr.device,obj.isTx,obj.chan,val));
        end
        
        function bw_val = get.bandwidth(obj)
            bw=libpointer('doublePtr',0);
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_GetLPFBW', obj.limesdr.device,obj.isTx,obj.chan,bw));
            bw_val=bw.value;
        end
        
        function set.antenna(obj,index)
            
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetAntenna', obj.limesdr.device,obj.isTx,obj.chan,index));
            
        end
        
        function ant_index = get.antenna(obj)
            ant_index= calllib('libLimeSuite', 'LMS_GetAntenna', obj.limesdr.device,obj.isTx,0);
        end
        
        function set.gain(obj,val)
            
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetNormalizedGain', obj.limesdr.device,obj.isTx,obj.chan,val));
        end
        
        function val = get.gain(obj)
            
            gain_val=libpointer('doublePtr',0);
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_GetNormalizedGain', obj.limesdr.device,obj.isTx,obj.chan,gain_val));
            val=gain_val.value;
        end
        
        function obj = limeSDR_XCVR(dev, dir, chan)
            
            if nargin < 3
                chan = 0;
            end
            
            if strcmpi(dir,'RX') == false && strcmpi(dir,'TX') == false
                error('Invalid direction specified');
            end
            
            obj.chan=chan;
            obj.limesdr=dev;
            
            if strcmpi(dir,'RX') == true
                obj.isTx = 0;
                obj.antenna=2;%LNA_L
            else
                obj.isTx = 1;
                obj.antenna=1;%TX_PATH1
            end
            obj.samplerate = 3e6;
            obj.frequency = 100e6;
            %  obj.bandwidth = 30e6;
            
            obj.running = false;
            
        end
        
        function enable(obj)
            obj.running = true;
            
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_EnableChannel', obj.limesdr.device,obj.isTx,obj.chan,1));
            stream=libstruct('lms_stream_t');
            
            stream.isTx=obj.isTx;
            stream.channel=obj.chan;
            stream.fifoSize=1024*128;
            stream.throughputVsLatency=1.0;
            
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_SetupStream',obj.limesdr.device, stream));
            
            if(obj.isTx)
                if obj.chan==0
                    obj.limesdr.tx0_stream=stream;
                else
                    obj.limesdr.tx1_stream=stream;
                end
                
            else
                if obj.chan==0
                    obj.limesdr.rx0_stream=stream;
                else
                    obj.limesdr.rx1_stream=stream;
                end
            end
            
        end
        
        function disable(obj)
            if(obj.isTx)
                if obj.chan==0
                    stream=obj.limesdr.tx0_stream;
                else
                    stream=obj.limesdr.tx1_stream;
                end
            else
                if obj.chan==0
                    stream=obj.limesdr.rx0_stream;
                else
                    stream=obj.limesdr.rx1_stream;
                end
            end
            
            if ~isempty(stream)
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_StopStream', stream));
            end
            
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_EnableChannel', obj.limesdr.device,obj.isTx,obj.chan,0));
            obj.running = false;
            
        end
        
    end
end