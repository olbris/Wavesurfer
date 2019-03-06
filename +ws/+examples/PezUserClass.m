classdef PezUserClass < ws.UserClass
    properties (Constant, Transient)  % Transient so doesn't get written to data files
        TrialSequenceModeOptions = {'all-1' 'all-2' 'alternating' 'random'} ;
    end

    properties (Constant, Transient, Access=protected)  % Transient so doesn't get written to data files
        DispenseToneVolumeWhenPlayed_ = 50   % percent of maximum
    end
    
    properties (Dependent)
        TrialSequenceMode
        
        DoPlayDispenseTone
        DispenseToneFrequency
        
        ToneFrequency1
        ToneDuration1
        DispenseDelay1
        DeliverPosition1X
        DeliverPosition1Y
        DeliverPosition1Z
        DispensePosition1ZOffset

        ToneFrequency2
        ToneDuration2
        DispenseDelay2
        DeliverPosition2X
        DeliverPosition2Y
        DeliverPosition2Z
        DispensePosition2ZOffset
        
        ReturnDelay
        
        TrialSequence  % 1 x sweepCount, each element 1 or 2        
        IsRunning
        IsResetEnabled
    end  % properties
    
    properties (Access=protected)
        TrialSequenceMode_ = 'alternating'  % can be 'all-1', 'all-2', 'alternating', or 'random'
        
        DoPlayDispenseTone_ = false  % boolean
        DispenseToneFrequency_ = 7000  % Hz        
        
        ToneFrequency1_ = 3000  % Hz
        ToneDuration1_ = 1  % s
        DispenseDelay1_ = 1  % s
        DeliverPosition1X_ =  51  % mm?
        DeliverPosition1Y_ =  64  % mm?
        DeliverPosition1Z_ = -73  % mm?
        DispensePosition1ZOffset_ = -21  % scalar, mm?, the vertical delta from the deliver position to the dispense position

        ToneFrequency2_ = 10000  % Hz
        ToneDuration2_ = 1  % s
        DispenseDelay2_ = 1  % s
        DeliverPosition2X_ =  60  % mm?
        DeliverPosition2Y_ =  64  % mm?
        DeliverPosition2Z_ = -73  % mm?
        DispensePosition2ZOffset_ = -30  % scalar, mm?
        
        ReturnDelay_ = 6  % s, the duration the piston holds at the dispense position
    end  % properties

    properties (Access=protected, Transient=true)
        PezDispenser_
        TrialSequence_
        Controller_
        IsRunning_ = false
    end
    
    methods
        function self = PezUserClass()
            % Creates the "user object"
            fprintf('Instantiating an instance of PezUserClass.\n');
        end
        
        function wake(self, rootModel)
            fprintf('Waking an instance of PezUserClass.\n');
            if isa(rootModel, 'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel ,
                ws.examples.PezController(self) ;
                   % Don't need to keep a ref, b/c this creates a figure, the callbacks of which
                   % hold references to the controller
            end
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('An instance of PezUserClass is being deleted.\n');
            if ~isempty(self.Controller_) && isvalid(self.Controller_) ,
                delete(self.Controller_) ;
            end
        end
        
        % These methods are called in the frontend process
        function startingRun(self, wsModel)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            fprintf('About to start a run in PezUserClass.\n');
            sweepCount = wsModel.NSweepsPerRun ;
            if isequal(self.TrialSequenceMode, 'all-1') 
                self.TrialSequence_ = repmat(1, [1 sweepCount]) ;  %#ok<REPMAT>
            elseif isequal(self.TrialSequenceMode, 'all-2') 
                self.TrialSequence_ = repmat(2, [1 sweepCount]) ;
            elseif isequal(self.TrialSequenceMode, 'alternating')
                self.TrialSequence_ = repmat([1 2], [1 ceil(sweepCount/2)]) ;                
            elseif isequal(self.TrialSequenceMode, 'random') 
                trialSequence = randi(2, [1 sweepCount]) ;
                self.TrialSequence_ = trialSequence ;
            else
                error('Unrecognized TrialSequenceMode: %s', self.TrialSequenceMode) ;
            end
            self.IsRunning_ = true ;
            self.PezDispenser_ = ModularClient('COM3') ;
            self.PezDispenser_.open() ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function completingRun(self,wsModel)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('Completed a run in PezUserClass.\n');
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function stoppingRun(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a run in PezUserClass.\n');
            self.PezDispenser_.abort() ;
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end        
        
        function abortingRun(self,wsModel)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('Oh noes!  A run aborted in PezUserClass.\n');
            self.PezDispenser_.abort() ;
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function startingSweep(self,wsModel)
            % Called just before each sweep
            fprintf('About to start a sweep in PezUserClass.\n');
            sweepIndex = wsModel.NSweepsCompletedInThisRun + 1 ;
            trialType = self.TrialSequence_(sweepIndex) ;
            
            % Note well: We have to permute the permission coordinates so that they match
            % user expectations, given the orientation of the stage.  To the Arduino,
            % increasing x means "piston more extended".  If we used Ardunio-native coords, 
            %
            %   increasing x == upward
            %   increasing y == rightward
            %   increasing z == away
            %
            % (All of these are from the POV of the experiemnter, sitting in front of the
            % rig.)
            %
            % We want increasing z to be upwards, and to keep the coordinate system
            % right-handed.  So we'll have a "user" coord system s.t.:
            %
            %   increasing x == rightward
            %   increasing y == away
            %   increasing z == upward
            %
            % Thus:
            %
            %   user x == arduino y
            %   user y == arduino z
            %   uzer z == arduino x
            %
            % I.e.
            %   arduino x == user z
            %   arduino y == user x
            %   arduino z == user y
            %
            % So, long story short, we permute the user coords to get arduino coords
            
            if trialType == 1 ,
                self.PezDispenser_.toneFrequency('setValue', self.ToneFrequency1) ;
                self.PezDispenser_.toneDuration('setValue', self.ToneDuration1) ;
                self.PezDispenser_.dispenseDelay('setValue', self.DispenseDelay1) ;
                self.PezDispenser_.deliverPosition('setValue', [self.DeliverPosition1Z self.DeliverPosition1X self.DeliverPosition1Y]) ;
                self.PezDispenser_.dispenseChannelPosition('setValue', self.DispensePosition1ZOffset) ;
            else
                self.PezDispenser_.toneFrequency('setValue', self.ToneFrequency2) ;
                self.PezDispenser_.toneDuration('setValue', self.ToneDuration2) ;
                self.PezDispenser_.dispenseDelay('setValue', self.DispenseDelay2) ;
                self.PezDispenser_.deliverPosition('setValue', [self.DeliverPosition2Z self.DeliverPosition2X self.DeliverPosition2Y]) ;
                self.PezDispenser_.dispenseChannelPosition('setValue', self.DispensePosition2ZOffset) ;
            end
            self.PezDispenser_.returnDelayMin('setValue', self.ReturnDelay) ;
            self.PezDispenser_.returnDelayMax('setValue', self.ReturnDelay) ;
            self.PezDispenser_.toneDelayMin('setValue', 0) ;  % Just to make sure, since we're not using toneDelay any more
            self.PezDispenser_.toneDelayMax('setValue', 0) ;            
            dispenseToneVolume = ws.fif(self.DoPlayDispenseTone, self.DispenseToneVolumeWhenPlayed_, 0) ;
            self.PezDispenser_.dispenseToneVolume('setValue', dispenseToneVolume) ;
            self.PezDispenser_.dispenseToneFrequency('setValue', self.DispenseToneFrequency) ;
        end
        
        function completingSweep(self,wsModel)  %#ok<INUSD>
            % Called after each sweep completes
            fprintf('Completed a sweep in PezUserClass.\n');
        end
        
        function stoppingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a sweep in PezUserClass.\n');
        end        
        
        function abortingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('Oh noes!  A sweep aborted in PezUserClass.\n');
        end        
        
        function dataAvailable(self, wsModel)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
            %analogData = wsModel.getLatestAIData();
            %digitalData = wsModel.getLatestDIData();  %#ok<NASGU>
            %nScans = size(analogData,1);
            %fprintf('Just read %d scans of data in PezUserClass.\n', nScans);                                    
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            %nScans = size(analogData,1);
            %fprintf('Just acquired %d scans of data in PezUserClass.\n', nScans);                                    
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller)  %#ok<INUSD>
            % Called just before each episode
            fprintf('About to start an episode in PezUserClass.\n');
        end
        
        function completingEpisode(self,refiller)  %#ok<INUSD>
            % Called after each episode completes
            fprintf('Completed an episode in PezUserClass.\n');
        end
        
        function stoppingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('User stopped an episode in PezUserClass.\n');
        end        
        
        function abortingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('Oh noes!  An episode aborted in PezUserClass.\n');
        end
    end  % public methods
        
    methods
        function result = get.TrialSequence(self)
            result = self.TrialSequence_ ;
        end
        
        function result = get.TrialSequenceMode(self)
            result = self.TrialSequenceMode_ ;
        end
        
        function result = get.ToneFrequency1(self)
            result = self.ToneFrequency1_ ;
        end
        
        function result = get.DeliverPosition1X(self)
            result = self.DeliverPosition1X_ ;
        end
        
        function result = get.DeliverPosition1Y(self)
            result = self.DeliverPosition1Y_ ;
        end
        
        function result = get.DeliverPosition1Z(self)
            result = self.DeliverPosition1Z_ ;
        end
        
        function result = get.DispensePosition1ZOffset(self)
            result = self.DispensePosition1ZOffset_ ;
        end
        
        function result = get.ToneFrequency2(self)
            result = self.ToneFrequency2_ ;
        end
        
        function result = get.DeliverPosition2X(self)
            result = self.DeliverPosition2X_ ;
        end
        
        function result = get.DeliverPosition2Y(self)
            result = self.DeliverPosition2Y_ ;
        end
        
        function result = get.DeliverPosition2Z(self)
            result = self.DeliverPosition2Z_ ;
        end
        
        function result = get.DispensePosition2ZOffset(self)
            result = self.DispensePosition2ZOffset_ ;
        end
        
        function result = get.ToneDuration1(self)
            result = self.ToneDuration1_ ;
        end
        
        function result = get.DispenseDelay1(self)
            result = self.DispenseDelay1_ ;
        end
        
        function result = get.ToneDuration2(self)
            result = self.ToneDuration2_ ;
        end
        
        function result = get.DispenseDelay2(self)
            result = self.DispenseDelay2_ ;
        end
        
        function result = get.ReturnDelay(self)
            result = self.ReturnDelay_ ;
        end
        
        function result = get.DispenseToneFrequency(self)
            result = self.DispenseToneFrequency_ ;
        end        
        
        function result = get.DoPlayDispenseTone(self)
            result = self.DoPlayDispenseTone_ ;
        end        
        
        function set.TrialSequenceMode(self, newValue) 
            if ~any(strcmp(newValue, self.TrialSequenceModeOptions))
                error('ws:invalidPropertyValue', ...
                      'TrialSequenceMode must be one of ''all-1'', ''all-2'', ''alternating'', or ''random''') ;
            end
            self.TrialSequenceMode_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end        
                
        function set.ToneFrequency1(self, newValue)
            self.checkValue_('ToneFrequency1', newValue) ;
            self.ToneFrequency1_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1X(self, newValue)
            self.checkValue_('DeliverPosition1X', newValue) ;
            self.DeliverPosition1X_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1Y(self, newValue)
            self.checkValue_('DeliverPosition1Y', newValue) ;
            self.DeliverPosition1Y_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1Z(self, newValue)
            self.checkValue_('DeliverPosition1Z', newValue) ;
            self.DeliverPosition1Z_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition1ZOffset(self, newValue)
            self.checkValue_('DispensePosition1ZOffset', newValue) ;
            self.DispensePosition1ZOffset_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneFrequency2(self, newValue)
            self.checkValue_('ToneFrequency2', newValue) ;
            self.ToneFrequency2_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2X(self, newValue)
            self.checkValue_('DeliverPosition2X', newValue) ;
            self.DeliverPosition2X_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2Y(self, newValue)
            self.checkValue_('DeliverPosition2Y', newValue) ;
            self.DeliverPosition2Y_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2Z(self, newValue)
            self.checkValue_('DeliverPosition2Z', newValue) ;
            self.DeliverPosition2Z_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition2ZOffset(self, newValue)
            self.checkValue_('DispensePosition2ZOffset', newValue) ;
            self.DispensePosition2ZOffset_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDuration1(self, newValue)
            self.checkValue_('ToneDuration1', newValue) ;
            self.ToneDuration1_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseDelay1(self, newValue)
            self.checkValue_('DispenseDelay1', newValue) ;
            self.DispenseDelay1_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDuration2(self, newValue)
            self.checkValue_('ToneDuration2', newValue) ;
            self.ToneDuration2_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseDelay2(self, newValue)
            self.checkValue_('DispenseDelay2', newValue) ;
            self.DispenseDelay2_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ReturnDelay(self, newValue)
            self.checkValue_('ReturnDelay', newValue) ;
            self.ReturnDelay_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseToneFrequency(self, newValue)
            self.checkValue_('DispenseToneFrequency', newValue) ;
            self.DispenseToneFrequency_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DoPlayDispenseTone(self, rawNewValue)
            self.checkValue_('DoPlayDispenseTone', rawNewValue) ;
            if islogical(rawNewValue) ,
                newValue = rawNewValue ;
            else
                newValue = (rawNewValue>0) ;
            end
            self.DoPlayDispenseTone_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function result = get.IsRunning(self)
            result = self.IsRunning_ ;            
        end
        
        function result = get.IsResetEnabled(self)
            result = ~self.IsRunning_ ;            
        end
        
        function reset(self)
            if self.IsResetEnabled ,
                self.PezDispenser_ = ModularClient('COM3') ;
                self.PezDispenser_.open() ;
                self.PezDispenser_.reset() ;
                %self.PezDispenser_.close() ;
                delete(self.PezDispenser_) ;
                self.PezDispenser_ = [] ;
            else
                error('Reset is not currently enabled.') ;
            end
        end
        
        function registerController(self, controller)
            self.Controller_ = controller ;
        end
        
        function clearController(self)
            self.Controller_ = [] ;
        end
        
    end  % public methods
    
    methods (Access=protected)
        function tellControllerToUpdateIfPresent_(self)
            if ~isempty(self.Controller_) ,
                self.Controller_.update() ;
            end
        end
        
        function checkValue_(self, propertyName, newValue)  %#ok<INUSL>
            if isequal(propertyName, 'DoPlayDispenseTone') ,
                if ~( isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && ~isnan(newValue))) ) ,
                    error('ws:invalidPropertyValue', 'DoPlayDispenseTone property value is invalid') ;
                end                                                    
            elseif isequal(propertyName, 'ReturnDelay') ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0.1<newValue ) ,
                    error('ws:invalidPropertyValue', 'ReturnDelay property value is invalid') ;
                end                                    
            elseif ~isempty(strfind(propertyName, 'Position')) ,  %#ok<STREMP>
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && (-100<=newValue) && (newValue<=+100) ) ,
                    error('ws:invalidPropertyValue', 'Position property value is invalid') ;
                end
            elseif ~isempty(strfind(propertyName, 'Duration')) ,  %#ok<STREMP>
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<=newValue ) ,
                    error('ws:invalidPropertyValue', 'Duration property value is invalid') ;
                end                    
            elseif ~isempty(strfind(propertyName, 'Delay')) ,  %#ok<STREMP>
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<=newValue ) ,
                    error('ws:invalidPropertyValue', 'Delay property value is invalid') ;
                end                    
            elseif ~isempty(strfind(propertyName, 'Frequency')) ,  %#ok<STREMP>
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<newValue ) ,
                    error('ws:invalidPropertyValue', 'Frequency property value is invalid') ;
                end                    
            else
                error('Unrecognized property name') ;
            end
        end
    end  % protected methods block
    
    methods (Access = protected)
        function out = getPropertyValue_(self, name)
            % This allows public access to private properties in certain limited
            % circumstances, like persisting.
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % This allows public access to private properties in certain limited
            % circumstances, like persisting.
            self.(name) = value;
        end
    end  % protected
    
end  % classdef

