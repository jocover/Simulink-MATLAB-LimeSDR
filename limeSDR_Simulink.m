classdef limeSDR_Simulink < matlab.System & ...
        matlab.system.mixin.Propagates & ...
        matlab.system.mixin.CustomIcon & ...
        matlab.system.mixin.internal.SampleTime
    %% Properties
    properties
        verbosity           = 'Info'    % limeSDR verbosity
        
        rx_frequency        = 915e6;    % Frequency [100e6, 3.8e9]
        
        rx0_gain =0.5;			% Gain [0, 1]
        rx1_gain =0.5;			% Gain [0, 1]
        
        tx_frequency = 920e6;    % Frequency [100e6, 3.8e9]      
	
        tx0_gain =0.5;		 % Gain [0, 1]
        tx1_gain =0.5;		 % Gain [0, 1]
    end
    
    
    
    properties(Nontunable)
        device_string       = '';       % Device specification string
        
        rx_samplerate       = 3e6;      % Sample rate
        rx_step_size        = 16384;	% Frame
        rx_timeout_ms       = 5000;     % Stream timeout (ms)
        
        rx0_bandwidth        = '1.5';    % LPF Bandwidth (MHz)
        rx0_antenna   = 2;              %1=LNA_H 2=LNA_L 3=LNA_W
        
        rx1_bandwidth        = '1.5';    % LPF Bandwidth (MHz)
        rx1_antenna   = 2;%1=LNA_H 2=LNA_L 3=LNA_W
        
     
        tx_samplerate       = 3e6;      % Sample rate
        tx_step_size        = 16384;	% Frame
        tx_timeout_ms       = 5000;     % Stream timeout (ms)
        
        tx0_bandwidth        = '1.5';    % LPF Bandwidth (MHz)
        tx0_antenna   = 1;               %1=TX_PATH1 2=TX_PATH2

        
        tx1_bandwidth        = '1.5';    % LPF Bandwidth (MHz)
        tx1_antenna   = 1;%1=TX_PATH1 2=TX_PATH2

    end
    
    properties(Logical, Nontunable)
        enable_rx0           = true;     % Enable Receiver
        enable_rx1           = false;     % Enable Receiver
        
        enable_tx0           = false;    % Enable Transmitter
        enable_tx1           = false;    % Enable Transmitter
        
    end
    
    properties(Hidden, Transient)
        rx0_bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
            });
        
        rx1_bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
            });
        
        tx0_bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
            });
        
        tx1_bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
            });
    end
    
    properties (Access = private)
        device = []
        running
    end
    
    %% Static Methods
    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl
            device_section_group = matlab.system.display.SectionGroup(...
                'Title', 'Device', ...
                'PropertyList', {'device_string' } ...
                );
            
            %%RX
            
            rx0_group = matlab.system.display.Section(...
                'Title','RX0 parameters',...
                'PropertyList',{'enable_rx0','rx0_antenna','rx0_bandwidth','rx0_gain'});
            
            rx1_group = matlab.system.display.Section(...
                'Title','RX1 parameters',...
                'PropertyList',{'enable_rx1','rx1_antenna','rx1_bandwidth','rx1_gain'});
            
            rx_stream_section = matlab.system.display.Section(...
                'Title', 'RX config', ...
                'PropertyList', {'rx_frequency','rx_samplerate', 'rx_timeout_ms', 'rx_step_size', } ...
                );
            
            rx_section_group = matlab.system.display.SectionGroup(...
                'Title', 'RX Configuration', ...
                'Sections', [ rx0_group, rx1_group, rx_stream_section] ...
                );
            
            %%TX
            
           tx0_group = matlab.system.display.Section(...
                'Title','TX0 parameters',...
                'PropertyList',{'enable_tx0','tx0_antenna','tx0_bandwidth','tx0_gain'});
            
            tx1_group = matlab.system.display.Section(...
                'Title','TX1 parameters',...
                'PropertyList',{'enable_tx1','tx1_antenna','tx1_bandwidth','tx1_gain'});
            
            tx_stream_section = matlab.system.display.Section(...
                'Title', 'TX config', ...
                'PropertyList', {'tx_frequency','tx_samplerate', 'tx_timeout_ms', 'tx_step_size', } ...
                );
            
            tx_section_group = matlab.system.display.SectionGroup(...
                'Title', 'TX Configuration', ...
                'Sections', [ tx0_group, tx1_group, tx_stream_section] ...
                );
            
            %     groups = [device_section_group,rx0_section_group,rx1_section_group, tx0_section_group, tx1_section_group ];
            groups = [device_section_group,rx_section_group,tx_section_group ];
            
        end
        
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = 'Interpreted execution';
        end
        
        function flag = showSimulateUsingImpl
            % Return false if simulation mode hidden in System block dialog
            flag = false;
        end
        
        function header = getHeaderImpl
            text = 'This block provides access to a LimeSDR device via limeSDR MATLAB bindings.';
            header = matlab.system.display.Header('limeSDR_Simulink', ...
                'Title', 'limeSDR', 'Text',  text ...
                );
        end
    end
    
    methods (Access = protected)
        %% Output setup
        function count = getNumOutputsImpl(obj)
            if obj.enable_rx0 == true
                count = 1;
            else
                count = 0;
            end
            
            if obj.enable_rx1 == true
                count = count + 1;
            end
        end
        
        function varargout = getOutputNamesImpl(obj)
            if obj.enable_rx0 == true
                varargout{1} = 'RX0 Samples';
                n = 2;
            else
                n = 1;
            end
            
            if obj.enable_rx1 ==true
                varargout{n} = 'RX1 Samples';
                n=n+1;
            end
        end
        
        function varargout = getOutputDataTypeImpl(obj)
            if obj.enable_rx0 == true
                varargout{1} = 'double';    % RX0 Samples
                n = 2;
            else
                n = 1;
            end
            
            if obj.enable_rx1 == true
                varargout{n} = 'double';    % RX1 Samples
            end
            
        end
        
        function st = getSampleTimeImpl(obj)
                st=1/obj.rx_samplerate*obj.rx_step_size;        
        end
        
        
        function varargout = getOutputSizeImpl(obj)
            if obj.enable_rx0 == true
                varargout{1} = [obj.rx_step_size 1];  % RX0 Samples
                n = 2;
            else
                n = 1;
            end
            
            if obj.enable_rx1 == true
                varargout{n} = [obj.rx_step_size 1];  % RX1 Samples
                n=n+1;
            end
        end
        
        function varargout = isOutputComplexImpl(obj)
            if obj.enable_rx0 == true
                varargout{1} = true;    % RX0 Samples
                n = 2;
            else
                n = 1;
            end
            
            if obj.enable_rx1 == true
                varargout{n} = true;   % RX1 Samples
                n = n + 1;
            end
        end
        
        function varargout  = isOutputFixedSizeImpl(obj)
            if obj.enable_rx0 == true
                varargout{1} = true;    % RX0 Samples
                n = 2;
            else
                n = 1;
            end
            
            if obj.enable_rx1 == true
                varargout{n} = true;    % RX1 Samples
            end
            
        end
        
        
        %% Input setup
        function count = getNumInputsImpl(obj)
            if obj.enable_tx0 == true
                count = 1;
            else
                count = 0;
            end
            
            if obj.enable_tx1 == true
                count=count+1;
            end
        end
        
        function varargout = getInputNamesImpl(obj)
            if obj.enable_tx0 == true
                varargout{1} = 'TX0 Samples';
                n = 2;
            else
                n = 1;
            end
            
            if obj.enable_tx1 == true
                varargout{n} = 'TX1 Samples';
            end
            
        end
        
        %% Property and Execution Handlers
        function icon = getIconImpl(~)
            icon = sprintf('LimeSDR');
        end
        
        function setupImpl(obj)
            
            %% Device setup
            obj.device = limeSDR(obj.device_string);
            
            %% RX0 Setup
            if obj.enable_rx0 == true
                obj.device.rx0.frequency  = obj.rx_frequency;
                obj.device.rx0.gain = obj.rx0_gain;
                obj.device.rx0.samplerate=obj.rx_samplerate;
                obj.device.rx0.antenna=obj.rx0_antenna;
            end
            
            %% RX1 Setup
            if obj.enable_rx1 == true
                obj.device.rx1.frequency  = obj.rx_frequency;
                obj.device.rx1.gain = obj.rx1_gain;
                obj.device.rx1.samplerate=obj.rx_samplerate;
                obj.device.rx1.antenna=obj.rx1_antenna;
            end
            
            %% TX0 Setup
            if obj.enable_tx0 == true
                     obj.device.tx0.frequency  = obj.tx_frequency;
                     obj.device.tx0.samplerate=obj.tx_samplerate;
                     obj.device.tx0.gain = obj.tx0_gain;
                     obj.device.tx0.antenna=obj.tx0_antenna;
            end
            
            if obj.enable_tx1 == true
                %% TX1 Setup
                       obj.device.tx1.frequency  = obj.tx_frequency;
                       obj.device.tx1.samplerate=obj.tx_samplerate;
                       obj.device.tx1.gain = obj.tx1_gain;
                       obj.device.tx1.antenna=obj.tx1_antenna;
            end
            obj.running=false;
            
        end
        
        function releaseImpl(obj)
            delete(obj.device);
        end
        
        function resetImpl(obj)
            obj.device.stop();
        end
        
        % Perform a read of received samples and an 'overrun' array that denotes whether
        % the associated samples is invalid due to a detected overrun.
        function varargout = stepImpl(obj, varargin)
            varargout = {};
            
            if obj.enable_rx0 == true
                if obj.device.rx0.running == false
                    obj.device.rx0.enable();
                end
            end
            
            if obj.enable_rx1 == true
                if obj.device.rx1.running == false
                    obj.device.rx1.enable();
                end
            end
            
            if obj.enable_tx0 == true
                if obj.device.tx0.running == false
                    obj.device.tx0.enable();
                end
            end
            
            if obj.enable_tx1 == true
                if obj.device.tx1.running == false
                    obj.device.tx1.enable();
                end
            end
            
            if ~obj.running
                obj.device.start();
                obj.running=true;
            end
            
            if obj.enable_rx0 == true
                
                [rx_samples0, ~] = obj.device.receive(obj.rx_step_size,0);
                varargout{1} = rx_samples0;
                out_idx = 2;
            else
                out_idx = 1;
            end
            
            if obj.enable_rx1 == true
                
                [rx_samples1, ~] = obj.device.receive(obj.rx_step_size,1);
                
                varargout{out_idx} = rx_samples1;
            end
            
            if obj.enable_tx0 == true
                obj.device.transmit(varargin{1},0);
                in_idx=2;
            else
                in_idx=1;
            end
            
            if obj.enable_tx1 == true
                if obj.device.tx1.running == false
                    obj.device.tx1.start();
                end
                obj.device.transmit(varargin{in_idx},1);
            end
        end
        
        function processTunedPropertiesImpl(obj)
            
            %% RX Properties
            
               if isChangedProperty(obj, 'rx_frequency')
                     if obj.enable_rx0 ==true
                        obj.device.rx0.frequency = obj.rx_frequency;
                     end
                     
                    if obj.enable_rx1 ==true
                        obj.device.rx1.frequency = obj.rx_frequency;
                     end
                    %disp('Updated RX frequency');
                end
            
            if obj.enable_rx0 ==true
                if isChangedProperty(obj, 'rx0_gain')
                    obj.device.rx0.gain = obj.rx0_gain;
                    %disp('Updated RX0 gain');
                end
            end
            
            if obj.enable_rx1 ==true
                if isChangedProperty(obj, 'rx1_gain')
                    obj.device.rx1.gain = obj.rx1_gain;
                    %disp('Updated RX1 gain');
                end
            end
            %% TX Properties
            
             if isChangedProperty(obj, 'tx_frequency')
                  if obj.enable_tx0 ==true
                    obj.device.tx0.frequency = obj.tx_frequency;
                  end
                  
                   if obj.enable_tx1 ==true
                       obj.device.tx1.frequency = obj.tx_frequency;
                   end
                    %disp('Updated TX frequency');
                end
            
            if obj.enable_tx0 ==true
                if isChangedProperty(obj, 'tx0_frequency')
                    obj.device.tx0.frequency = obj.tx0_frequency;
                    %disp('Updated TX frequency');
                end
                
                if isChangedProperty(obj, 'tx0_gain')
                    obj.device.tx0.gain = obj.tx0_gain;
                    %disp('Updated TX VGA1 gain');
                end
                
                
            end
            
            
            if obj.enable_tx1 ==true
                if isChangedProperty(obj, 'tx1_gain')
                    obj.device.tx1.gain = obj.tx1_gain;
                    %disp('Updated TX VGA1 gain');
                end           
            end
            
        end
        
        function validatePropertiesImpl(obj)
            if obj.enable_rx0 == false && obj.enable_tx0 == false && obj.enable_rx1 == false && obj.enable_tx1 == false
                warning('LimeSDR RX or TX is enabled. One or both should be enabled.');
            end
            
            %% Validate RX properties
            
            if obj.rx_timeout_ms < 0
                error('rx_timeout_ms must be >= 0.');
            end
            
            if obj.rx_step_size <= 0
                error('rx_step_size must be > 0.');
            end
            
            if obj.rx_samplerate < 160.0e3
                error('rx_samplerate must be >= 160 kHz.');
            elseif obj.rx_samplerate > 40e6
                error('rx_samplerate must be <= 40 MHz.')
            end
            
            if obj.rx_frequency < 100e3
                error('rx_frequency must be >= 100 kHz');
            elseif obj.rx_frequency > 3.8e9
                error('rx_frequency must be <= 3.8 GHz.');
            end
            
            if obj.rx0_gain < 0
                error('rx0_gain gain must be >= 0.');
            elseif obj.rx0_gain > 1
                error('rx0_gain gain must be <= 1.');
            end
            
            if obj.rx0_antenna <0
                error('rx0_antenna must be >= 0.');
            elseif obj.rx0_antenna >3
                error('rx0_antenna must be <= 3.');
            end
            
            
            if obj.rx1_gain < 0
                error('rx1_gain gain must be >= 0.');
            elseif obj.rx1_gain > 1
                error('rx1_gain gain must be <= 1.');
            end
            
            if obj.rx1_antenna <0
                error('rx1_antenna must be >= 0.');
            elseif obj.rx1_antenna >3
                error('rx1_antenna must be <= 3.');
            end
            
            %% Validate TX0 Properties
            
            if obj.tx_timeout_ms < 0
                error('tx_timeout_ms must be >= 0.');
            end
            
            if obj.tx_step_size <= 0
                error('tx_step_size must be > 0.');
            end
            
            if obj.tx_samplerate < 160.0e3
                error('tx_samplerate must be >= 160 kHz.');
            elseif obj.tx_samplerate > 40e6
                error('tx_samplerate must be <= 40 MHz.')
            end
            
            if obj.tx_frequency < 100e6;
                error('tx_frequency must be >= 100 kHz.');
            elseif obj.tx_frequency > 3.8e9
                error('tx_frequency must be <= 3.8 GHz.');
            end
            
            if obj.tx0_gain < 0
                error('tx_vga2 gain must be >= 0.');
            elseif obj.tx0_gain > 1
                error('tx_vga2 gain must be <= 1.');
            end
            
            if obj.tx0_antenna <0
                error('rx0_antenna must be >= 0.');
            elseif obj.tx0_antenna >2
                error('rx0_antenna must be <= 2.');
            end
            
            if obj.tx1_gain < 0
                error('tx1_gain gain must be >= 0.');
            elseif obj.tx1_gain > 1
                error('tx1_gain gain must be <= 1.');
            end
            
            if obj.tx1_antenna <0
                error('tx1_antenna must be >= 0.');
            elseif obj.tx1_antenna >2
                error('tx1_antenna must be <= 2.');
            end
            
        end
    end
end
