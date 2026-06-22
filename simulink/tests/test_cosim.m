classdef test_cosim < matlab.unittest.TestCase
%TEST_COSIM  Integration tests: Controller FMU + RiceCookerPlant Simulink model.
%
%   Tests are derived from the controller requirements document.
%
%   Run:
%       matlab -batch "r=runtests('test_cosim'); if any([r.Failed]),exit(1);end"
%
%   Test                    Requirement verified
%   ─────────────────────── ──────────────────────────────────────────────────
%   testIdleNoHeat          Idle: heaterPowerPct=0, ledColor=OFF, T=ambient
%   testCookingHeaterActivates Cooking start: heater>0, LED=GREEN, display=SOAK
%   testSoakingTemperature  WaterAbsorption PI targets TEMP_SOAKING_C (45°C)
%   testLidSafety           Lid-open safety: heater forced to 0

    properties (Constant)
        MODEL_NAME     = 'RiceCookerPlant'
        STOP_SHORT     = 10    % s — fast assertions
        STOP_SOAK      = 600   % s — 10 min, enough for soaking phase to establish
        STEP_SIZE      = 1     % s — matches FMU period

        % Controller constants (from requirements doc)
        TEMP_SOAKING_C = 45    % °C soaking PI setpoint
        LED_OFF        = 0     % enum: OFF
        LED_GREEN      = 1     % enum: GREEN (Soaking / DelayedCooking)
        LED_RED        = 2     % enum: RED  (Cooking phases)
        LED_YELLOW     = 3     % enum: YELLOW (KeepWarm)
        CHAR_S         = 83    % ASCII 'S' — first char of "SOAK"
    end

    % =====================================================================
    methods (TestClassSetup)
        function buildModelIfMissing(tc)
            thisDir = fileparts(mfilename('fullpath'));
            simulinkDir = fileparts(thisDir);
            modelDir = fullfile(simulinkDir, 'model');
            addpath(fullfile(simulinkDir, '..', 'fmu-controller'));   % FMU must be on path
            addpath(modelDir);
            addpath(thisDir);
            slxFile = fullfile(modelDir, [tc.MODEL_NAME '.slx']);
            if ~exist(slxFile, 'file')
                orig = cd(modelDir);
                cleanup = onCleanup(@() cd(orig));  %#ok<NASGU>
                build_model(tc.MODEL_NAME);
            end
            % Do NOT call load_system here — calling load_system before sim()
            % can lock the FMU temp directory and cause FMUParseError on the
            % first sim() call. Let each sim() manage the model lifecycle.
        end
    end

    methods (TestClassTeardown)
        function closeModel(tc)
            if bdIsLoaded(tc.MODEL_NAME)
                close_system(tc.MODEL_NAME, 0);
            end
        end
    end

    % =====================================================================
    methods (Test)

        % -----------------------------------------------------------------
        function testIdleNoHeat(tc)
            % Req: Idle state — heaterPowerPct=0, ledColor=OFF, no temperature rise.
            % All buttons off, lid closed → controller remains in Idle forever.
            out = tc.runSim(tc.STOP_SHORT, ...
                'btnStartStop', 0, 'btnDelay', 0, 'btnSetTime', 0, 'isLidOpen', 0);

            pwr = tc.yout(out, 'heaterPowerPct');
            led = tc.yout(out, 'colorLED');
            T   = tc.yout(out, 'tempC');

            tc.verifyEqual(max(abs(pwr)), 0, 'AbsTol', 1e-6, ...
                'Idle: heaterPowerPct must be 0 with no button pressed');
            tc.verifyEqual(max(led), tc.LED_OFF, ...
                'Idle: ledColor must be OFF (0) with no button pressed');
            tc.verifyLessThan(max(T) - min(T), 0.1, ...
                'Idle: temperature must not change without heater activity');
        end

        % -----------------------------------------------------------------
        function testCookingHeaterActivates(tc)
            % Req: btnStartStop → Cooking → WaterAbsorption phase.
            %   heaterPowerPct > 0 (PI control active)
            %   ledColor = GREEN (1) during WaterAbsorption / Soaking
            %   displayText[0] = 'S' (ASCII 83) for "SOAK"
            out = tc.runSim(tc.STOP_SHORT, ...
                'btnStartStop', 1, 'btnDelay', 0, 'btnSetTime', 0, 'isLidOpen', 0);

            pwr  = tc.yout(out, 'heaterPowerPct');
            led  = tc.yout(out, 'colorLED');
            disp = tc.yout(out, 'displayText');   % N-by-6 integer matrix

            tc.verifyGreaterThan(max(pwr), 0, ...
                'Cooking/Soaking: heaterPowerPct must be > 0 after btnStartStop');
            tc.verifyTrue(any(led == tc.LED_GREEN), ...
                'Cooking/Soaking: ledColor must show GREEN (1) during WaterAbsorption');
            tc.verifyTrue(any(disp(:) == tc.CHAR_S), ...
                'Cooking/Soaking: displayText must contain ''S'' (ASCII 83) for "SOAK"');
        end

        % -----------------------------------------------------------------
        function testSoakingTemperature(tc)
            % Req: WaterAbsorption phase — PI controller targets TEMP_SOAKING_C = 45°C.
            % After 10 min with btnStartStop active, temperature must be in the
            % soaking band [30, 55]°C (setpoint ± tolerance for PI steady-state).
            out = tc.runSim(tc.STOP_SOAK, ...
                'btnStartStop', 1, 'btnDelay', 0, 'btnSetTime', 0, 'isLidOpen', 0);

            T = tc.yout(out, 'tempC');

            tc.verifyGreaterThan(max(T), 30, ...
                'Soaking: temperature must rise above 30°C (PI heating active)');
            tc.verifyLessThan(max(T), 55, ...
                'Soaking: temperature must stay below 55°C during soaking phase');
        end

        % -----------------------------------------------------------------
        function testDisplayTextSoaking(tc)
            % Req: During WaterAbsorption, display shows "SOAK".
            % displayText is a 6-element integer vector per timestep.
            % Expected during soaking: [83 79 65 75 0 0]  ↔  'S','O','A','K',\0,\0
            out = tc.runSim(tc.STOP_SHORT, ...
                'btnStartStop', 1, 'btnDelay', 0, 'btnSetTime', 0, 'isLidOpen', 0);

            disp = tc.yout(out, 'displayText');   % N-by-6 double matrix

            % At least one complete "SOAK" row must be present
            soakRows = disp(:,1)==83 & disp(:,2)==79 & disp(:,3)==65 & disp(:,4)==75;
            tc.verifyTrue(any(soakRows), ...
                'WaterAbsorption: displayText must spell "SOAK" ([83 79 65 75 ...]) at least once');
        end

        % -----------------------------------------------------------------
        function testDisplayTextIdle(tc)
            % Req: In Idle state, display shows "IDLE".
            % displayText expected during Idle: [73 68 76 69 0 0]  ↔  'I','D','L','E',\0,\0
            out = tc.runSim(tc.STOP_SHORT, ...
                'btnStartStop', 0, 'btnDelay', 0, 'btnSetTime', 0, 'isLidOpen', 0);

            disp = tc.yout(out, 'displayText');   % N-by-6 double matrix
            t    = out.yout{8}.Values.Time;

            % Skip t=0 (uninitialized FMU output before first compute cycle)
            afterInit = t > 0;
            d = disp(afterInit, :);

            idleRows = d(:,1)==73 & d(:,2)==68 & d(:,3)==76 & d(:,4)==69;
            tc.verifyTrue(all(idleRows), ...
                'Idle: displayText must spell "IDLE" ([73 68 76 69 ...]) at every sample after t=0');
        end

    end

    % =====================================================================
    methods (Access = private)

        function out = runSim(tc, stopTime, varargin)
            % Build SimulationInput from named button/lid arguments, run sim.
            %
            % Fixed plant inputs for all tests:
            %   tempExt=20°C, volWaterInit=0.5 kg, volRiceInit=3e-4 m^3
            %
            % Dataset is built in strict port order (positional matching):
            %   Port 1: tempExt (double)
            %   Port 2: volWaterInit (double)
            %   Port 3: volRiceInit (double)
            %   Port 4: btnStartStop (logical)
            %   Port 5: btnDelay (logical)
            %   Port 6: btnSetTime (logical)
            %   Port 7: isLidOpen (logical)
            simIn = Simulink.SimulationInput(tc.MODEL_NAME);
            simIn = setModelParameter(simIn, ...
                'StartTime',      '0', ...
                'StopTime',       num2str(stopTime), ...
                'Solver',         'ode23', ...
                'MaxStep',        num2str(tc.STEP_SIZE), ...
                'SaveOutput',     'on', ...
                'SaveFormat',     'Dataset', ...
                'OutputSaveName', 'yout');

            % Parse named arguments → struct.
            args = struct('btnStartStop',0,'btnDelay',0,'btnSetTime',0,'isLidOpen',0);
            for k = 1:2:numel(varargin)
                args.(varargin{k}) = varargin{k+1};
            end

            % Plant constants (double).
            plant = {20, 0.5, 3e-4};
            % Boolean controller inputs (logical).
            bools = {logical(args.btnStartStop), logical(args.btnDelay), ...
                     logical(args.btnSetTime),   logical(args.isLidOpen)};

            ds = Simulink.SimulationData.Dataset;
            for k = 1:3
                ts = timeseries(double([plant{k}; plant{k}]), [0; stopTime]);
                ds = addElement(ds, ts);
            end
            for k = 1:4
                ts = timeseries(logical([bools{k}; bools{k}]), [0; stopTime]);
                ds = addElement(ds, ts);
            end
            simIn = setExternalInput(simIn, ds);
            out = sim(simIn);
        end

        function data = yout(~, out, portName)
            % Return raw Data array for a named outport.
            % Outport order from build_model.m:
            %   1:tempC  2:massWaterKg  3:massWaterPct  4:volRiceM3
            %   5:volRicePct  6:heaterPowerPct  7:colorLED  8:displayText
            portIdx = struct( ...
                'tempC',1,'massWaterKg',2,'massWaterPct',3,'volRiceM3',4, ...
                'volRicePct',5,'heaterPowerPct',6,'colorLED',7,'displayText',8);
            data = double(out.yout{portIdx.(portName)}.Values.Data);
        end

    end
end

