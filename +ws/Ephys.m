classdef Ephys < ws.Subsystem
    properties (Dependent=true)
        %TestPulseElectrodeCommandChannelName
        %TestPulseElectrodeMonitorChannelName
        %TestPulseElectrodeAmplitude
        %TestPulseElectrodeIndex  % index of the currently selected test pulse electrode *within the array of all electrodes*
        %TestPulseElectrodes
        TestPulseElectrodesCount
        %TestPulseElectrodeMode  % mode of the current TP electrode (VC/CC)        
        AmplitudePerTestPulseElectrode
        %TestPulseElectrode
        %Monitor
        %IsTestPulsing
        %DoSubtractBaseline
        %TestPulseElectrodeName
        DidLastElectrodeUpdateWork
        AreSoftpanelsEnabled
        IsDoTrodeUpdateBeforeRunSensible
        TestPulseElectrodeNames
        TestPulseElectrodeIndex
    end
    
    properties (Access = protected)
        ElectrodeManager_
        TestPulser_
    end
    
    properties (Dependent=true, SetAccess=immutable)
        %ElectrodeManager  % provides public access to ElectrodeManager_
        %TestPulser  % provides public access to TestPulser_
    end    
      
    events
        UpdateTestPulser
    end
    
    methods
        function self = Ephys()
            self@ws.Subsystem() ;
            self.IsEnabled=true;            
            self.ElectrodeManager_ = ws.ElectrodeManager() ;    % no longer needs parent
            self.TestPulser_ = ws.TestPulser() ;  % no longer needs parent
            %self.TestPulser_.setNElectrodes_(self.ElectrodeManager_.TestPulseElectrodesCount) ;
        end
        
        function delete(self)
            self.TestPulser_ = [] ;
            self.ElectrodeManager_ = [] ;
        end
        
%         function out = get.TestPulser(self)
%             out=self.TestPulser_;
%         end
        
%         function out = get.ElectrodeManager(self)
%             out=self.ElectrodeManager_;
%         end
        
        function electrodeMayHaveChanged(self, electrodeIndex, propertyName)
            % Called by the ElectrodeManager to notify that the electrode
            % may have changed.
            % Currently, tells TestPulser about the change, and the parent
            % WavesurferModel.
            self.ElectrodeManager_.electrodeMayHaveChanged(electrodeIndex, propertyName) ;
            self.TestPulser_.electrodeMayHaveChanged(electrodeIndex, propertyName) ;
            %self.Parent.electrodeMayHaveChanged(electrodeIndex,propertyName);
        end

%         function electrodeWasAdded(self,electrode)
%             % Called by the ElectrodeManager when an electrode is added.
%             % Currently, informs the TestPulser of the change.
%             self.TestPulser_.electrodeWasAdded(electrode);
%         end

%         function electrodesRemoved(self)
%             % Called by the ElectrodeManager when one or more electrodes
%             % are removed.
%             % Currently, informs the TestPulser of the change.
%             testPulseElectrodesAfter = self.TestPulseElectrodes ;
%             self.TestPulser_.electrodesRemoved(testPulseElectrodesAfter) ;
%             self.Parent.electrodesRemoved() ;
%         end

        function didSetAnalogChannelUnitsOrScales(self)
            self.TestPulser_.didSetAnalogChannelUnitsOrScales();
        end       
        
        function isElectrodeMarkedForTestPulseMayHaveChanged(self)
            %testPulseElectrodes = self.TestPulseElectrodes ;
            isElectrodeMarkedForTestPulseAfter = self.ElectrodeManager_.getIsElectrodeMarkedForTestPulse_() ;
            self.TestPulser_.isElectrodeMarkedForTestPulseMayHaveChanged(isElectrodeMarkedForTestPulseAfter) ;
        end
                
        function startingRun(self)  %#ok<MANU>
            % Update all the gains and modes that are associated with smart
            % electrodes if checkbox is checked
%             if self.ElectrodeManager_.DoTrodeUpdateBeforeRun
%                 self.ElectrodeManager_.updateSmartElectrodeGainsAndModes() ;
%             end
        end
        
        function completingRun(self) %#ok<MANU>
        end
        
        function abortingRun(self) %#ok<MANU>
        end
        
        function didSetAcquisitionSampleRate(self,newValue)
            self.TestPulser_.didSetAcquisitionSampleRate(newValue) ;
        end        
        
        function didSetIsInputChannelActive(self) 
            self.ElectrodeManager_.didSetIsInputChannelActive() ;
            self.TestPulser_.didSetIsInputChannelActive() ;
        end
        
        function didSetIsDigitalOutputTimed(self)
            self.ElectrodeManager_.didSetIsDigitalOutputTimed() ;
        end
        
        function didChangeNumberOfInputChannels(self)
            self.ElectrodeManager_.didChangeNumberOfInputChannels();
            self.TestPulser_.didChangeNumberOfInputChannels();
        end        
        
        function didChangeNumberOfOutputChannels(self)
            self.ElectrodeManager_.didChangeNumberOfOutputChannels();
            self.TestPulser_.didChangeNumberOfOutputChannels();
        end        

        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue)
            self.ElectrodeManager_.didSetAnalogInputChannelName(didSucceed, oldValue, newValue) ;
        end        

        function didSetAnalogOutputChannelName(self, didSucceed, oldValue, newValue)
            self.ElectrodeManager_.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue) ;
        end        
    end  % methods block
    
    methods         
        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Model(self) ;            
            % delete some property names that are defined in subclasses
            % that don't need to go into the header file
            propNames=setdiff(propNamesRaw, ...
                              {'TestPulser'}) ;
        end  % function 
    end  % public methods block    
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end
    end  % protected methods block
    
    methods
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
            self.TestPulser_.disableBroadcasts() ;
            self.ElectrodeManager_.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.TestPulser_.enableBroadcastsMaybe() ;
            self.ElectrodeManager_.enableBroadcastsMaybe() ;
            self.enableBroadcastsMaybe() ;
        end
        
        function updateEverythingAfterProtocolFileOpen_(self)
            self.ElectrodeManager_.broadcast('Update') ;
            self.TestPulser_.broadcast('Update') ;
        end        
    end  % methods block 

    methods
        function mimic(self, other)
            % Cause self to resemble other.
            
            % Disable broadcasts for speed
            %self.disableBroadcasts();
            self.ElectrodeManager_.disableBroadcasts();
            self.TestPulser_.disableBroadcasts();
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            % all the "configurable" props in this class hold scalar
            % ws.Model objects, so this is simple
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'ElectrodeManager_', 'TestPulser_'})) ,
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
                    target = self.(thisPropertyName) ;
                    target.mimic(source);  % all the props in this class hold scalar ws.Model objects
                else
                    if isprop(other,thisPropertyName)
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end                    
                end
            end
            
            % Ensure self-consistency of self
            %self.TestPulser_.setNElectrodes_(self.ElectrodeManager_.TestPulseElectrodesCount) ;
            
            % Re-enable broadcasts
            self.TestPulser_.enableBroadcastsMaybe();
            self.ElectrodeManager_.enableBroadcastsMaybe();
            %self.enableBroadcastsMaybe();
            
            % Broadcast updates for sub-models and self, now that
            % everything is in sync, and should be self-consistent
            self.TestPulser_.broadcast('Update');
            self.ElectrodeManager_.broadcast('Update');
            %self.broadcast('Update');  % is this necessary?
        end  % function
        
        function didSetDeviceName(self, deviceName)
            %fprintf('ws.Triggering::didSetDevice() called\n') ;
            %dbstack
            self.TestPulser_.didSetDeviceName(deviceName) ;
        end        
        
        function result = getTestPulseElectrodeProperty(self, propertyName)
            electrodeIndex = self.TestPulseElectrodeIndex ;
            if isempty(electrodeIndex) ,
                result = [] ;
            else
                result = self.getElectrodeProperty(electrodeIndex, propertyName) ;
            end
%             electrodeName = self.TestPulseElectrodeName ;
%             electrode = self.ElectrodeManager_.getElectrodeByName(electrodeName) ;
%             if isempty(electrode) ,
%                 value = '' ;
%             else
%                 value = electrode.(propertyName) ;
%             end
        end
    end
    
    methods (Access=protected)        
        function setTestPulseElectrodeProperty_(self, propertyName, newValue)
            electrodeIndex = self.TestPulseElectrodeIndex ;            
            %electrode = self.ElectrodeManager_.getElectrodeByName(electrodeIndex) ;
            if ~isempty(electrodeIndex) ,
                set.setElectrodeProperty(electrodeIndex, propertyName, newValue) ;
            end
        end
    end
    
    methods
%         function result = get.TestPulseElectrodeCommandChannelName(self)
%             result = self.getTestPulseElectrodeProperty('CommandChannelName') ;
%         end
        
%         function result = get.TestPulseElectrodeMonitorChannelName(self)
%             result = self.getTestPulseElectrodeProperty('MonitorChannelName') ;
%         end
        
%         function result = get.TestPulseElectrodeAmplitude(self)
%             result = self.getTestPulseElectrodeProperty('TestPulseAmplitude') ;
%         end
%         
%         function result=get.TestPulseElectrodes(self)
%             electrodeManager=self.ElectrodeManager_;
%             result=electrodeManager.TestPulseElectrodes;
%         end

        function result=get.TestPulseElectrodesCount(self)
            electrodeManager=self.ElectrodeManager_ ;
            result=electrodeManager.TestPulseElectrodesCount ;
        end
        
        function result=get.AmplitudePerTestPulseElectrode(self)
            % Get the amplitudes of the test pulse for all the
            % marked-for-test-pulsing electrodes, as a double array.            
            electrodeManager=self.ElectrodeManager_;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %resultAsCellArray={testPulseElectrodes.TestPulseAmplitude};
            result=cellfun(@(electrode)(electrode.TestPulseAmplitude), ...
                           testPulseElectrodes);
        end  % function 
        
%         function set.TestPulseElectrodeAmplitude(self, newValue)  % in units of the electrode command channel
%             if ~isempty(self.TestPulseElectrodeName) ,
%                 if ws.isString(newValue) ,
%                     newValueAsDouble = str2double(newValue) ;
%                 elseif isnumeric(newValue) && isscalar(newValue) ,
%                     newValueAsDouble = double(newValue) ;
%                 else
%                     newValueAsDouble = nan ;  % isfinite(nan) is false
%                 end
%                 if isfinite(newValueAsDouble) ,
%                     self.setTestPulseElectrodeProperty_('TestPulseAmplitude', newValueAsDouble) ;
%                     self.TestPulser_.clearExistingSweepIfPresent_() ;
%                 else
%                     self.broadcast('UpdateTestPulser') ;
%                     error('ws:invalidPropertyValue', ...
%                           'TestPulseElectrodeAmplitude must be a finite scalar');
%                 end
%             end                
%             self.broadcast('UpdateTestPulser') ;
%         end  % function         
        
%         function result = get.TestPulseElectrode(self)
%             electrodeName = self.TestPulseElectrodeName ;            
%             electrodeManager = self.ElectrodeManager_ ;
%             result = electrodeManager.getElectrodeByName(electrodeName) ;
%         end  % function 
        
        function result = getTestPulseMonitorTrace_(self)
%             currentElectrodeName = self.TestPulseElectrodeName ;
%             if isempty(currentElectrodeName)
%                 result = [] ; 
%             else
%                 %electrodes = self.ElectrodeManager_.TestPulseElectrodes ;
%                 electrodeNames = self.ElectrodeManager_.TestPulseElectrodeNames ;
%                 isCurrentElectrode=cellfun(@(testElectrodeName)(isequal(currentElectrodeName, testElectrodeName)), electrodeNames) ;
%                 monitorPerElectrode = self.TestPulser_.getMonitorPerElectrode_() ;
%                 if isempty(monitorPerElectrode) ,
%                     result = [] ;
%                 else
%                     result = monitorPerElectrode(:,isCurrentElectrode) ;
%                 end
%             end
            
            electrodeIndex = self.TestPulseElectrodeIndex ;
            if isempty(electrodeIndex) ,
                result = [] ; 
            else
                isElectrodeMarkedForTestPulse = self.getIsElectrodeMarkedForTestPulse_() ;
                indexWithinTPElectrodes = ws.indexWithinSubsetFromIndex(electrodeIndex, isElectrodeMarkedForTestPulse) ;
                monitorPerElectrode = self.TestPulser_.getMonitorPerElectrode_() ;
                if isempty(monitorPerElectrode) ,
                    result = [] ;
                else
                    result = monitorPerElectrode(:,indexWithinTPElectrodes) ;
                end
            end
            
            
        end  % function         
        
        function result = getTestPulseMonitorTraceTimeline_(self, fs)
            result = self.TestPulser_.getTime_(fs) ;
        end  % function                 
        
%         function result = get.TestPulseElectrodeIndex(self)
%             name = self.TestPulseElectrodeName ;
%             if isempty(name) ,
%                 result = zeros(1,0) ; 
%             else
%                 result = self.ElectrodeManager_.getElectrodeIndexByName(name) ;
%             end
%         end  % function         
        
%         function result = get.TestPulseElectrodeMode(self)
%             electrodeName = self.TestPulseElectrodeName ;
%             if isempty(electrodeName) ,
%                 result = [] ;
%             else
%                 result = self.ElectrodeManager_.getElectrodePropertyByName(electrodeName, 'Mode') ;
%             end
%         end  % function        
        
%         function set.TestPulseElectrodeMode(self, newValue)            
%             electrodeIndex = self.TestPulseElectrodeIndex ;  % index within all electrodes
%             self.ElectrodeManager_.setElectrodeModeOrScaling_(electrodeIndex, 'Mode', newValue) ;
%         end  % function        
        
        function prepForTestPulsing_(self, ...
                                     fs, ...
                                     isVCPerTestPulseElectrode, ...
                                     isCCPerTestPulseElectrode, ...
                                     commandTerminalIDPerTestPulseElectrode, ...
                                     monitorTerminalIDPerTestPulseElectrode, ...
                                     commandChannelScalePerTestPulseElectrode, ...
                                     monitorChannelScalePerTestPulseElectrode, ...
                                     deviceName, ...
                                     gainOrResistanceUnitsPerTestPulseElectrode)
            testPulseElectrodeIndex = self.TestPulseElectrodeIndex ;
            indexOfTestPulseElectrodeWithinTestPulseElectrodes = ...
                self.ElectrodeManager_.indexWithinTestPulseElectrodesFromElectrodeIndex(testPulseElectrodeIndex) ;
            %testPulseElectrode = self.ElectrodeManager_.getElectrodeByIndex_(testPulseElectrodeIndex) ;
            
            amplitudePerTestPulseElectrode = self.AmplitudePerTestPulseElectrode ;
            
            nTestPulseElectrodes = self.ElectrodeManager_.TestPulseElectrodesCount ;
            %gainOrResistanceUnitsPerTestPulseElectrode = self.getGainOrResistanceUnitsPerTestPulseElectrode() ;
            self.TestPulser_.prepForStart_(indexOfTestPulseElectrodeWithinTestPulseElectrodes, ...
                                           amplitudePerTestPulseElectrode, ...
                                           fs, ...
                                           nTestPulseElectrodes, ...
                                           gainOrResistanceUnitsPerTestPulseElectrode, ...
                                           isVCPerTestPulseElectrode, ...
                                           isCCPerTestPulseElectrode, ...
                                           commandTerminalIDPerTestPulseElectrode, ...
                                           monitorTerminalIDPerTestPulseElectrode, ...
                                           commandChannelScalePerTestPulseElectrode, ...
                                           monitorChannelScalePerTestPulseElectrode, ...
                                           deviceName) ;
        end

        function startTestPulsing_(self)
            self.TestPulser_.start_() ;            
        end
        
        function stopTestPulsing_(self)
            self.TestPulser_.stop_() ;            
        end
        
        function abortTestPulsing_(self)
            self.TestPulser_.abort_() ;
        end
        
        function result = getIsTestPulsing_(self)
            result = self.TestPulser_.getIsRunning_() ;
        end
        
%         function changeTestPulserReadiness_(self, delta)
%             self.TestPulser_.changeReadiness(delta) ;
%         end

%         function changeElectrodeManagerReadiness_(self, delta)
%             self.ElectrodeManager_.changeReadiness(delta) ;
%         end
        
%         function toggleIsTestPulsing(self)
%             if self.IsTestPulsing , 
%                 self.stopTestPulsing_() ;
%             else
%                 self.startTestPulsing_() ;
%             end
%         end
        
        function result = getGainOrResistancePerTestPulseElectrode_(self)
            rawValue = self.TestPulser_.getGainOrResistancePerElectrode_() ;
            if isempty(rawValue) ,                
                nTestPulseElectrodes = self.ElectrodeManager_.TestPulseElectrodesCount ;
                result = nan(1,nTestPulseElectrodes) ;
            else
                result = rawValue ;
            end
        end

%         function result = getGainOrResistanceUnitsPerTestPulseElectrode(self)
%             result = self.TestPulser_.getGainOrResistanceUnitsPerElectrode_() ;
%         end        
        
%         function [gainOrResistance, gainOrResistanceUnits] = getGainOrResistancePerTestPulseElectrodeWithNiceUnits(self)
%             rawGainOrResistance = self.getGainOrResistancePerTestPulseElectrode() ;
%             rawGainOrResistanceUnits = self.getGainOrResistanceUnitsPerTestPulseElectrode() ;
%             % [gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;  
%             [gainOrResistanceUnits,gainOrResistance] = ...
%                 ws.convertDimensionalQuantityToEngineering(rawGainOrResistanceUnits,rawGainOrResistance) ;
%         end
        
        function result = getDoSubtractBaselineInTestPulseView_(self)
            result = self.TestPulser_.getDoSubtractBaseline_() ;
        end        
        
        function setDoSubtractBaselineInTestPulseView_(self, newValue)            
            self.TestPulser_.setDoSubtractBaseline_(newValue) ;
        end    
        
%         function result = get.TestPulseElectrodeName(self)
%             electrodeIndex = self.TestPulser_.getElectrodeIndex_() ;
%             if isempty(electrodeIndex) ,
%                 result = '' ;
%             else
%                 result = self.getElectrodeProperty(electrodeIndex, 'Name') ;
%             end
%             %value=self.TestPulser_.getElectrodeName_() ;
%         end

        function set.TestPulseElectrodeIndex(self, newValue)
            if isempty(newValue) ,
                self.TestPulser_.setElectrodeIndex_([]) ;
            else
                if isnumeric(newValue) && isscalar(newValue) && 1<=newValue && newValue<=self.getElectrodeCount_() && newValue==round(newValue) ,
                    newElectrodeIndex = double(newValue) ;
                    self.TestPulser_.setElectrodeIndex_(newElectrodeIndex) ;
                end
            end
            self.broadcast('UpdateTestPulser');
        end

        function result = get.TestPulseElectrodeIndex(self)
            result = self.TestPulser_.getElectrodeIndex_() ;
        end
        
        function setTestPulseElectrodeByName(self, newValue)
            if isempty(newValue) ,
                self.TestPulseElectrodeIndex = [] ;
            else
                % Check that the newValue is an available electrode, unless we
                % can't get a list of electrodes.
                electrodeManager = self.ElectrodeManager_ ;
                electrodeNames = electrodeManager.TestPulseElectrodeNames ;
                newElectrodeIndex = find(strcmp(newValue, electrodeNames), 1) ;
                if ~isempty(newElectrodeIndex) ,
                    self.TestPulseElectrodeIndex = newElectrodeIndex ;
                end
            end
        end
        
        function setTestPulseYLimits_(self, newValue)
            self.TestPulser_.setYLimits_(newValue) ;
        end
        
        function result = getTestPulseYLimits_(self)
            result = self.TestPulser_.getYLimits_() ;
        end
        
        function result = getTestPulseElectrodes_(self)
            result = self.ElectrodeManager_.getTestPulseElectrodes_() ;
        end
        
        function result = getGainOrResistanceUnitsPerTestPulseElectrodeCached_(self)
            result = self.TestPulser_.getGainOrResistanceUnitsPerTestPulseElectrodeCached_() ;
        end                
        
        function zoomInTestPulseView_(self)
            self.TestPulser_.zoomIn_() ;
        end  % function
        
        function zoomOutTestPulseView_(self)
            self.TestPulser_.zoomOut_() ;
        end  % function
        
        function scrollUpTestPulseView_(self)
            self.TestPulser_.scrollUp_() ;
        end  % function
        
        function scrollDownTestPulseView_(self)
            self.TestPulser_.scrollDown_() ;
        end  % function
        
        function result = getTestPulseDuration_(self) 
            result = self.TestPulser_.getPulseDuration_() ;
        end
        
        function setTestPulseDuration_(self, newValue) 
            self.TestPulser_.setPulseDuration_(newValue) ;
        end        
        
        function result = getIsAutoYInTestPulseView_(self) 
            result = self.TestPulser_.getIsAutoY_() ;
        end
        
        function setIsAutoYInTestPulseView_(self, newValue) 
            self.TestPulser_.setIsAutoY_(newValue) ;
        end

        function result = getIsAutoYRepeatingInTestPulseView_(self) 
            result = self.TestPulser_.getIsAutoYRepeating_() ;
        end
        
        function setIsAutoYRepeatingInTestPulseView_(self, newValue) 
            self.TestPulser_.setIsAutoYRepeating_(newValue) ;
        end
        
        function value = getUpdateRateInTestPulseView_(self)
            value = self.TestPulser_.getUpdateRate_() ;
        end        
        
%         function result = getIsTestPulserReady(self)
%             result = self.TestPulser_.IsReady ;
%         end
        
        function result = getTestPulserReference_(self) 
            result = self.TestPulser_ ;
        end
            
        function setElectrodeProperty_(self, electrodeIndex, propertyName, newValue)
            self.ElectrodeManager_.setElectrodeProperty_(electrodeIndex, propertyName, newValue) ;
            self.electrodeMayHaveChanged(electrodeIndex, propertyName) ;
        end
        
        function setElectrodeModeAndScalings_(self,...
                                              electrodeIndex, ...
                                              newMode, ...
                                              newCurrentMonitorScaling, ...
                                              newVoltageMonitorScaling, ...
                                              newCurrentCommandScaling, ...
                                              newVoltageCommandScaling,...
                                              newIsCommandEnabled)
            self.ElectrodeManager_.setElectrodeModeAndScalings_(electrodeIndex, ...
                                                                newMode, ...
                                                                newCurrentMonitorScaling, ...
                                                                newVoltageMonitorScaling, ...
                                                                newCurrentCommandScaling, ...
                                                                newVoltageCommandScaling,...
                                                                newIsCommandEnabled) ;
            self.electrodeMayHaveChanged(electrodeIndex, '') ;
        end  % function
        
        function result = areAllElectrodesTestPulsable(self, aiChannelNames, aoChannelNames)
            result = self.ElectrodeManager_.areAllElectrodesTestPulsable(aiChannelNames, aoChannelNames) ;
        end  % function
        
        function result = isElectrodeOfType(self, queryType)
            result = self.ElectrodeManager_.isElectrodeOfType(queryType) ;
        end  % function
        
        function [areAnyOfThisType, ...
                  indicesOfThisTypeOfElectrodes, ...
                  overallError, ...
                  modes, ...
                  currentMonitorScalings, voltageMonitorScalings, currentCommandScalings, voltageCommandScalings, ...
                  isCommandEnabled] = ...
                 probeHardwareForSmartElectrodeModesAndScalings_(self, smartElectrodeType)
            [areAnyOfThisType, ...
             indicesOfThisTypeOfElectrodes, ...
             overallError, ...
             modes, ...
             currentMonitorScalings, voltageMonitorScalings, currentCommandScalings, voltageCommandScalings, ...
             isCommandEnabled] = ...
                self.ElectrodeManager_.probeHardwareForSmartElectrodeModesAndScalings_(smartElectrodeType) ;
        end  % function
        
        function reconnectWithSmartElectrodes_(self)
            % Close and repoen the connection to any smart electrodes
            self.ElectrodeManager_.reconnectWithSmartElectrodes_() ;
        end  % function
        
        function doNeedToUpdateGainsAndModes = setElectrodeType_(self, electrodeIndex, newValue)
            % can only change the electrode type if softpanels are
            % enabled.  I.e. only when WS is _not_ in command of the
            % gain settings
            doNeedToUpdateGainsAndModes = self.ElectrodeManager_.setElectrodeType_(electrodeIndex, newValue) ;
        end  % function
        
        function doUpdateSmartElectrodeGainsAndModes = setElectrodeIndexWithinType_(self, electrodeIndex, newValue)
            doUpdateSmartElectrodeGainsAndModes = self.ElectrodeManager_.setElectrodeIndexWithinType_(electrodeIndex, newValue) ;
        end
        
        function doUpdateSmartElectrodeGainsAndModes = setIsInControlOfSoftpanelModeAndGains_(self, newValue)
            doUpdateSmartElectrodeGainsAndModes = self.ElectrodeManager_.setIsInControlOfSoftpanelModeAndGains_(newValue) ;
        end
        
        function newElectrodeIndex = addNewElectrode_(self)
            newElectrodeIndex = self.ElectrodeManager_.addNewElectrode_() ;
            %electrodeName = self.ElectrodeManager_.getElectrodeProperty(electrodeIndex, 'Name') ;
            isElectrodeMarkedForTestPulseAfter = self.ElectrodeManager_.getIsElectrodeMarkedForTestPulse_() ;
            self.TestPulser_.electrodeWasAdded_(newElectrodeIndex, isElectrodeMarkedForTestPulseAfter) ;
            %self.electrodeWasAdded(electrodeIndex);
        end
        
        function removeMarkedElectrodes_(self)
            wasRemoved = self.ElectrodeManager_.removeMarkedElectrodes_() ;
            isElectrodeMarkedForTestPulseAfter = self.getIsElectrodeMarkedForTestPulse_ ;
            self.TestPulser_.electrodesRemoved_(wasRemoved, isElectrodeMarkedForTestPulseAfter) ;
        end

        function setDoTrodeUpdateBeforeRun_(self, newValue)
            self.ElectrodeManager_.setDoTrodeUpdateBeforeRun_(newValue) ;
        end        

        function result = getDoTrodeUpdateBeforeRun_(self)
            result = self.ElectrodeManager_.getDoTrodeUpdateBeforeRun_() ;
        end 
        
%         function setElectrodeModeOrScaling_(self, electrodeIndex, propertyName, newValue)
%             self.ElectrodeManager_.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;
%         end
        
        function result = getIsElectrodeMarkedForTestPulse_(self)
            result = self.ElectrodeManager_.getIsElectrodeMarkedForTestPulse_();
        end
        
        function setIsElectrodeMarkedForTestPulse_(self, newValue)
            self.ElectrodeManager_.setIsElectrodeMarkedForTestPulse_(newValue);
            self.isElectrodeMarkedForTestPulseMayHaveChanged() ; 
        end

        function result = getIsElectrodeMarkedForRemoval_(self)
            result = self.ElectrodeManager_.getIsElectrodeMarkedForRemoval_();
        end
        
        function setIsElectrodeMarkedForRemoval_(self, newValue)
            self.ElectrodeManager_.setIsElectrodeMarkedForRemoval_(newValue);
        end

        function result = getElectrodeProperty(self, electrodeIndex, propertyName)
            result = self.ElectrodeManager_.getElectrodeProperty(electrodeIndex, propertyName) ;
        end  % function

        function result = getElectrodeCount_(self)
            result = self.ElectrodeManager_.getElectrodeCount_();
        end
        
%         function electrode = getElectrodeByIndex_(self, electrodeIndex)
%             electrode = self.ElectrodeManager_.getElectrodeByIndex_(electrodeIndex) ;
%         end    
        
        function result = getIsInControlOfSoftpanelModeAndGains_(self)
            result = self.ElectrodeManager_.getIsInControlOfSoftpanelModeAndGains_() ;
        end

%         function setIsInControlOfSoftpanelModeAndGains_(self, newValue)
%             self.ElectrodeManager_.setIsInControlOfSoftpanelModeAndGains_(newValue) ;
%         end

        function [channelScalesFromElectrodes, isChannelScaleEnslaved] = getMonitorScalingsByName(self, aiChannelNames)
            [channelScalesFromElectrodes, isChannelScaleEnslaved] = self.ElectrodeManager_.getMonitorScalingsByName(aiChannelNames) ;
        end
        
        function [channelScalesFromElectrodes, isChannelScaleEnslaved] = getCommandScalingsByName(self, aoChannelNames)
            [channelScalesFromElectrodes, isChannelScaleEnslaved] = self.ElectrodeManager_.getCommandScalingsByName(aoChannelNames) ;
        end
        
        function [queryChannelUnits,isQueryChannelScaleManaged] = getMonitorUnitsByName(self,queryChannelNamesRaw)
            [queryChannelUnits,isQueryChannelScaleManaged] = self.ElectrodeManager_.getMonitorUnitsByName(queryChannelNamesRaw) ;
        end

        function [channelUnitsFromElectrodes, isChannelScaleEnslaved] = getCommandUnitsByName(self, channelNames)
            [channelUnitsFromElectrodes, isChannelScaleEnslaved] = self.ElectrodeManager_.getCommandUnitsByName(channelNames) ;
        end            
        
        function result = getNumberOfElectrodesClaimingMonitorChannel(self, queryChannelNames)
            result = self.ElectrodeManager_.getNumberOfElectrodesClaimingMonitorChannel(queryChannelNames) ;
        end
        
        function result = areAllMonitorAndCommandChannelNamesDistinct(self)
            result = self.ElectrodeManager_.areAllMonitorAndCommandChannelNamesDistinct() ;
        end  % function
        
        function value = getNumberOfElectrodesClaimingCommandChannel(self,queryChannelNames)
            value = self.ElectrodeManager_.getNumberOfElectrodesClaimingCommandChannel(queryChannelNames) ;
        end

        function result = areAnyElectrodesCommandable(self)
            result = self.ElectrodeManager_.areAnyElectrodesCommandable() ;
        end  % function
        
        function result = get.DidLastElectrodeUpdateWork(self)
            result = self.ElectrodeManager_.DidLastElectrodeUpdateWork ;
        end
        
        function result = get.AreSoftpanelsEnabled(self)
            result = self.ElectrodeManager_.AreSoftpanelsEnabled ;
        end

        function set.AreSoftpanelsEnabled(self, newValue)
            self.ElectrodeManager_.AreSoftpanelsEnabled = newValue ;
        end
        
        function result = doesElectrodeHaveCommandOnOffSwitch(self)
            result = self.ElectrodeManager_.doesElectrodeHaveCommandOnOffSwitch() ;
        end        
        
        function result = get.IsDoTrodeUpdateBeforeRunSensible(self)
            result = self.ElectrodeManager_.IsDoTrodeUpdateBeforeRunSensible() ;
        end        
        
        function result = areAnyElectrodesSmart(self)
            result = self.ElectrodeManager_.areAnyElectrodesSmart() ;
        end        
        
        function result = get.TestPulseElectrodeNames(self)
            result = self.ElectrodeManager_.TestPulseElectrodeNames ;
        end
        
%         function result = getElectrodeManagerReference_(self)
%             % Should be used as little as possible, and never by consumer code.
%             % And eventually should be removed.
%             result = self.ElectrodeManager_ ;
%         end
           
        function subscribeMeToElectrodeManagerEvent(self,subscriber,eventName,propertyName,methodName)
            self.ElectrodeManager_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
        end
        
        function subscribeMeToTestPulserEvent(self,subscriber,eventName,propertyName,methodName)
            self.TestPulser_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
        end
        
    end  % public methods block

end  % classdef
