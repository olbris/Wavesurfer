classdef Display < ws.Subsystem   %& ws.EventSubscriber
    %Display Manages the display
    
    properties (Dependent = true)
        UpdateRate  % the rate at which the scopes are updated, in Hz
        XOffset  % the x coord at the left edge of the scope windows
        XSpan  % the trace duration shown in the scope windows
        IsXSpanSlavedToAcquistionDuration
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsXSpanSlavedToAcquistionDurationSettable
          % true iff IsXSpanSlavedToAcquistionDuration is currently
          % settable
        IsXSpanSlavedToSweepDurationIfFinite
        PlotModels  % a cell array of ws.ScopeModel objects
        NPlots
        IsGridOn
        AreColorsNormal        
        DoShowButtons        
    end

    properties (Access = protected)
        IsAnalogChannelShownWhenActive_
        IsDigitalChannelShownWhenActive_
        YLimitsPerAnalogChannel_
        %PlotModels_  % a cell array of ws.ScopeModel objects
        XSpan_ 
        UpdateRate_
        XAutoScroll_   % if true, x limits of all scopes will change to accomodate the data as it is acquired
        IsXSpanSlavedToSweepDurationIfFinite_
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsGridOn_ = true
        AreColorsNormal_ = true  % if false, colors are inverted, approximately
        DoShowButtons_ = true % if false, don't show buttons in the figure  
    end
    
    properties (Access = protected, Transient=true)
        XOffset_
        ClearOnNextData_
        CachedDisplayXSpan_
        BufferFactor_ = 1        
    end
    
    events
        Update
        %DidSetScopeIsVisibleWhenDisplayEnabled
        %DidSetIsXSpanSlavedToAcquistionDuration        
        DidSetUpdateRate
        UpdateXSpan
        %ChannelAdded
        DataAdded
        DataCleared
        DidSetXUnits
        %WindowVisibilityNeedsToBeUpdated
        UpdateXAxisLimits
        UpdateYLimits
        %UpdateAreYLimitsLockedTightToData        
    end  % events

    
    methods
        function self = Display(parent)
            self@ws.Subsystem(parent) ;
            self.PlotModels_ = cell(1,0) ;
            self.XOffset_ = 0;  % s
            self.XSpan_ = 1;  % s
            self.UpdateRate_ = 10;  % Hz
            self.XAutoScroll_ = false ;
            self.IsXSpanSlavedToSweepDurationIfFinite_ = true ;
        end
        
        function delete(self)
            %self.removeScopes_();
            self.PlotModels_ = cell(1,0) ;
        end
        
        function value = get.UpdateRate(self)
            value = self.UpdateRate_;
        end
        
        function value = get.PlotModels(self)
            value = self.PlotModels_ ;
        end
        
        function set.UpdateRate(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                    newValue = max(0.1,min(newValue,10)) ;
                    self.UpdateRate_ = newValue;
                else
                    self.broadcast('DidSetUpdateRate');
                    error('most:Model:invalidPropVal', ...
                          'UpdateRate must be a scalar finite positive number') ;
                end
            end
            self.broadcast('DidSetUpdateRate');
        end
        
        function value = get.XSpan(self)
            import ws.*
            if self.IsXSpanSlavedToAcquistionDuration ,
                value=1;  % s, fallback value
                wavesurferModel=self.Parent;
                if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                    return
                end
%                 acquisition=wavesurferModel.Acquisition;
%                 if isempty(acquisition) || ~isvalid(acquisition),
%                     return
%                 end
                duration=wavesurferModel.SweepDuration;
                value=fif(isfinite(duration),duration,1);
            else
                value = self.XSpan_;
            end
        end
        
        function set.XSpan(self, newValue)            
            if ws.isASettableValue(newValue) ,
                if self.IsXSpanSlavedToAcquistionDuration ,
                    % don't set anything
                else
                    if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                        self.XSpan_ = double(newValue);
                        for idx = 1:numel(self.PlotModels) ,
                            self.PlotModels_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
                        end
                    else
                        self.broadcast('UpdateXSpan');
                        error('most:Model:invalidPropVal', ...
                              'XSpan must be a scalar finite positive number') ;
                    end
                end
            end
            self.broadcast('UpdateXSpan');            
        end  % function
                
        function value = get.XOffset(self)
            value = self.XOffset_;
        end
                
        function set.XOffset(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                    self.XOffset_ = double(newValue);
                    for idx = 1:numel(self.PlotModels)
                        self.PlotModels_{idx}.XOffset = newValue;
                    end
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'XOffset must be a scalar finite number') ;
                end
            end
            self.broadcast('Update');
        end
        
        function value = get.IsXSpanSlavedToSweepDurationIfFinite(self)
            value = self.IsXSpanSlavedToSweepDurationIfFinite_ ;
        end
        
        function value = get.IsXSpanSlavedToAcquistionDuration(self)
            if self.Parent.AreSweepsContinuous ,
                value = false ;
            else
                value = self.IsXSpanSlavedToSweepDurationIfFinite_;
            end
        end  % function
        
        function set.IsXSpanSlavedToAcquistionDuration(self,newValue)
            if self.IsXSpanSlavedToAcquistionDurationSettable ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && isfinite(newValue))) ,
                    self.IsXSpanSlavedToSweepDurationIfFinite_ = logical(newValue) ;
                    for idx = 1:numel(self.PlotModels) ,
                        self.PlotModels_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
                    end
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'IsXSpanSlavedToAcquistionDuration must be a logical scalar, or convertible to one') ;
                end
            end
            self.broadcast('Update');            
        end
        
        function value = get.IsXSpanSlavedToAcquistionDurationSettable(self)
            value = self.Parent.AreSweepsFiniteDuration ;
        end  % function       
        
        function self=didSetAnalogChannelUnitsOrScales(self)
            plotModels=self.PlotModels;
            for i=1:length(plotModels) ,
                plotModels{i}.didSetAnalogChannelUnitsOrScales();
            end
        end       
        
        function didSetDeviceName(self)  %#ok<MANU>
            %self.initializePlotModels_() ;
        end
        
        function addPlot_(self, scopeTag, scopeTitle, channelNames)
            if isempty(scopeTag)
                scopeTag = sprintf('Scope_%d', self.NPlots + 1);
            end
            if isempty(scopeTitle)
                scopeTitle = sprintf('Scope %d', self.NPlots + 1);
            end
            
            % Create the scope model
            scopeModel = ws.ScopeModel(self, ...
                                       'Tag', scopeTag, ...
                                       'Title', scopeTitle);
            
            % add the channels to the scope model                          
            nChannels=length(channelNames);
            for i = 1:nChannels
                channelName = channelNames{i};
                scopeModel.addChannel(channelName);
            end
            
            % Add the new scope to PlotModels
            self.PlotModels_{end + 1} = scopeModel;
            %self.IsScopeVisibleWhenDisplayEnabled(end+1) = true;

            % We want to know if the visibility of the scope changes
            %scopeModel.addlistener('Visible', 'PostSet', @self.scopeVisibleDidChange);
            %scopeModel.subscribeMe(self,'PostSet','Visible','scopeVisibleDidChange');
            
            % Let anyone who cares know that the number of scopes has
            % changed
            self.broadcast('Update');
        end

%         function registerScopeController(self,scopeController)
%             %scopeController.subscribeMe(self,'ScopeVisibilitySet','','scopeVisibleDidChange');
%          end

        function removeScope_(self, index)
            self.PlotModels_(index) = [];
            self.broadcast('Update');
        end
        
        function removeScopes_(self)
            if ~isempty(self.PlotModels_) ,
                self.PlotModels_ = cell(1,0);
                self.broadcast('Update');
            end
        end
        
        function toggleIsVisibleWhenDisplayEnabled(self,scopeIndex)
            originalState = self.PlotModels{scopeIndex}.IsVisibleWhenDisplayEnabled ;
            % self.PlotModels_{scopeIndex}.IsVisibleWhenDisplayEnabled = ~originalState ;  
            %   Doing things with the single line above doesn't work, b/c
            %   self.PlotModels_{scopeIndex} is set to empty for a time, and
            %   that causes havoc for the some of the event handlers that
            %   fire when IsVisibleWhenDisplayEnabled is set.  I don't
            %   understand why that element is briefly set to empty, but
            %   doing things as below fixes it.  -- ALT, 2015-08-04
            theScopeModel = self.PlotModels_{scopeIndex} ;
            theScopeModel.IsVisibleWhenDisplayEnabled = ~originalState ;
        end
        
        function startingRun(self)
            self.XOffset = 0;
            self.XSpan = self.XSpan;  % in case user has zoomed in on one or more scopes, want to reset now
            self.XAutoScroll_ = (self.Parent.AreSweepsContinuous) ;
        end  % function
        
        function completingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end
        
        function stoppingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end
        
        function abortingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end
        
        function didAddAnalogInputChannel(self)
            self.IsAnalogChannelShownWhenActive_ = [self.IsAnalogChannelShownWhenActive_ true] ;
            self.YLimsPerAnalogChannel_ = [self.YLimsPerAnalogChannel_ ; ...
                                           -10 +10] ;
            self.broadcast('Update');            
%             channelNames = self.Parent.Acquisition.AnalogChannelNames ;            
%             newChannelName = channelNames{end} ;
%             prototypeScopeTag=sprintf('Channel_%s', newChannelName);
%             scopeTag = ws.Display.tagFromString(prototypeScopeTag);  % this is a static method call
%             scopeTitle=sprintf('Channel %s', newChannelName);
%             channelNamesForNewScope={newChannelName};
%             self.addPlot_(scopeTag, scopeTitle, channelNamesForNewScope);
        end
        
        function didAddDigitalInputChannel(self)
            self.IsDigitalChannelShownWhenActive_ = [self.IsDigitalChannelShownWhenActive_ true] ;
            self.broadcast('Update');            
%             % Add a scope to match the new channel (newly added channels
%             % are always active)
%             channelNames = self.Parent.Acquisition.DigitalChannelNames ;            
%             newChannelName = channelNames{end} ;
%             prototypeScopeTag=sprintf('Channel_%s', newChannelName);
%             scopeTag = ws.Display.tagFromString(prototypeScopeTag);  % this is a static method call
%             scopeTitle=sprintf('Channel %s', newChannelName);
%             channelNamesForNewScope={newChannelName};
%             self.addPlot_(scopeTag, scopeTitle, channelNamesForNewScope);
        end

        function didDeleteAnalogInputChannels(self, isToBeDeleted)            
            self.IsAnalogChannelShownWhenActive_ = self.IsAnalogChannelShownWhenActive_(isToBeDeleted) ;
            self.YLimsPerAnalogChannel_ = self.YLimsPerAnalogChannel_(isToBeDeleted,:) ; ...
            self.broadcast('Update');                        
            %self.removeScopesByName_(nameOfRemovedChannels) ;
        end
        
        function didDeleteDigitalInputChannels(self, isToBeDeleted)            
            self.IsDigitalChannelShownWhenActive_ = self.IsDigitalChannelShownWhenActive_(isToBeDeleted) ;
            self.broadcast('Update');                        
%             self.removeScopesByName_(nameOfRemovedChannels) ;
        end
        
%         function didRemoveDigitalInputChannel(self, nameOfRemovedChannel)
%             self.removeScopeByName(nameOfRemovedChannel) ;
%         end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            if didSucceed , 
                %self.renameScope_(oldValue, newValue) ;
                self.broadcast('UpdateChannelNames') ;
            end
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            if didSucceed , 
                %self.renameScope_(oldValue, newValue) ;
                self.broadcast('UpdateChannelNames') ;
            end
        end
        
%         function removeScopesByName_(self, namesOfChannelsToRemove)
%             self.disableBroadcasts() ;
%             nChannels = length(namesOfChannelsToRemove) ;
%             for i = 1:nChannels ,
%                 channelName = namesOfChannelsToRemove{i} ;
%                 self.removeScopeByName_(channelName) ;
%             end
%             self.enableBroadcastsMaybe() ;
%             self.broadcast('Update');
%         end  % function
        
%         function removeScopeByName_(self, nameOfChannelToRemove)
%             [theScope, indexOfTheScope] = self.getScopeByName_(nameOfChannelToRemove) ;
%             if ~isempty(theScope) ,
%                 self.removeScope_(indexOfTheScope) ;
%             end
%         end  % function
        
        function set.IsGridOn(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.IsGridOn_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'IsGridOn must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.IsGridOn(self)
            result = self.IsGridOn_ ;
        end
            
        function set.AreColorsNormal(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.AreColorsNormal_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'AreColorsNormal must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.AreColorsNormal(self)
            result = self.AreColorsNormal_ ;
        end
            
        function set.DoShowButtons(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.DoShowButtons_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'DoShowButtons must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.DoShowButtons(self)
            result = self.DoShowButtons_ ;
        end
        
        function zoomIn(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+0.5*yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
        function zoomOut(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+2*yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
        function scrollUp(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
        function scrollDown(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
    end  % public methods block
    
    methods (Access=protected)
%         function [theScope, indexOfTheScope] = getScopeByName_(self, channelName)
%             nScopes = self.NPlots ;
%             didFindIt = false ;
%             for i = 1:nScopes ,
%                 thisScope = self.PlotModels{i} ;
%                 thisScopeChannelNames = thisScope.ChannelNames ;
%                 if ~isempty(thisScopeChannelNames) ,                    
%                     thisScopeChannelName = thisScopeChannelNames{1} ;
%                     if isequal(thisScopeChannelName,channelName) ,                        
%                         theScope = thisScope ;
%                         indexOfTheScope = i ;
%                         didFindIt = true ;
%                         break
%                     end
%                 end
%             end
%             if ~didFindIt ,
%                 theScope = [] ;
%                 indexOfTheScope = [] ;
%             end
%         end
        
%         function renameScope_(self, oldChannelName, newChannelName)
%             theScope = self.getScopeByName_(oldChannelName) ;
%             if ~isempty(theScope) ,
%                 prototypeNewScopeTag = sprintf('Channel_%s', newChannelName) ;
%                 newScopeTag = ws.Display.tagFromString(prototypeNewScopeTag) ;  % this is a static method call
%                 newScopeTitle = sprintf('Channel %s', newChannelName) ;
%                 %newChannelNames = {newChannelName} ;
%                 theScope.ChannelName = newChannelName ;
%                 theScope.Title = newScopeTitle ;
%                 theScope.Tag = newScopeTag ;
%             end
%         end
        
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.CachedDisplayXSpan_)
                self.XSpan = self.CachedDisplayXSpan_;
            end
            self.CachedDisplayXSpan_ = [];
        end        
        
%         function initializePlotModels_(self)
%             % Set up the initial set of scope models, one per AI channel
%             activeChannelNames = self.Parent.Acquisition.ActiveChannelNames;
%             for iChannel = 1:length(activeChannelNames) ,
%                 thisChannelName=activeChannelNames{iChannel};
%                 prototypeScopeTag=sprintf('Channel_%s', thisChannelName);
%                 scopeTag=self.tagFromString(prototypeScopeTag);  % this is a static method call
%                 scopeTitle=sprintf('Channel %s', thisChannelName);
%                 channelNames={thisChannelName};
%                 self.addScope(scopeTag, scopeTitle, channelNames);
%             end
%             %self.addScope('All_Channels','All Channels', activeChannelNames);            
%         end        
    end
        
    methods    
        function startingSweep(self)
            self.ClearOnNextData_ = true;
        end
        
        function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSL,INUSD>
            %fprintf('Display::dataAvailable()\n');
            %dbstack
            %T=zeros(4,1);
            %ticId=tic();                     
            if self.ClearOnNextData_
                %fprintf('About to clear scopes...\n');
                for sdx = 1:numel(self.PlotModels)
                    self.PlotModels{sdx}.clearData();
                end
            end            
            self.ClearOnNextData_ = false;
            %T(1)=toc(ticId);
            
            % update the x offset
            if self.XAutoScroll_ ,                
                scale=min(1,self.XSpan);
                tNudged=scale*ceil(100*t/scale)/100;  % Helps keep the axes aligned to tidy numbers
                xOffsetNudged=tNudged-self.XSpan;
                if xOffsetNudged>self.XOffset ,
                    self.XOffset_=xOffsetNudged;
                end
            end
            %T(2)=toc(ticId);

            % Feed the data to the scopes
            %T=zeros(3,1);
            activeInputChannelNames=self.Parent.Acquisition.ActiveChannelNames;
            isActiveChannelAnalog =  self.Parent.Acquisition.IsChannelAnalog(self.Parent.Acquisition.IsChannelActive);
            for sdx = 1:numel(self.PlotModels)
                % Figure out which channels go in this scope, and the
                % corresponding channel names
                % Although this looks like it might be slow, in practice it
                % takes negligible time compared to the call to
                % ScopeModel.addChannel() below.
                %TInner=zeros(1,2);
                %ticId2=tic();
                channelNamesForThisScope = cell(1,0);
                jInAnalogData = [];                
                jInDigitalData = [];                
                NActiveAnalogChannels = sum(self.Parent.Acquisition.IsAnalogChannelActive);
                for cdx = 1:length(activeInputChannelNames)
                    %channelName = sprintf('Acq_%d', inputTerminalIDs(cdx));
                    channelName=activeInputChannelNames{cdx};
                    if any(strcmp(channelName, self.PlotModels{sdx}.ChannelNames)) ,
                        channelNamesForThisScope{end + 1} = channelName; %#ok<AGROW>
                        if isActiveChannelAnalog(cdx)
                            jInAnalogData(end + 1) = cdx; %#ok<AGROW>
                        else
                            jInDigitalData(end + 1) = cdx - NActiveAnalogChannels; %#ok<AGROW>
                        end
                    end
                end
                %TInner(1)=toc(ticId2);
                
                % Add the data for the appropriate channels to this scope
                if ~isempty(jInAnalogData) ,
                    dataForThisScope=scaledAnalogData(:, jInAnalogData);
                    self.PlotModels{sdx}.addData(channelNamesForThisScope, dataForThisScope, self.Parent.Acquisition.SampleRate, self.XOffset_);
                end
                if ~isempty(jInDigitalData) ,
                    dataForThisScope=bitget(rawDigitalData, jInDigitalData);
                    self.PlotModels{sdx}.addData(channelNamesForThisScope, dataForThisScope, self.Parent.Acquisition.SampleRate, self.XOffset_);
                end
                %TInner(2)=toc(ticId2);
            %fprintf('    In Display.dataAvailable() loop: %10.3f %10.3f\n',TInner);
            end
            %fprintf('In Display dataAvailable(): %20g %20g %20g\n',T);
            %T(3)=toc(ticId);
            
            %T(4)=toc(ticId);
            %fprintf('In Display.dataAvailable(): %10.3f %10.3f %10.3f %10.3f\n',T);
            %T=toc(ticId);
            %fprintf('Time in Display.dataAvailable(): %7.3f s\n',T);
        end
        
        function didSetAreSweepsFiniteDuration(self)
            % Called by the parent to notify of a change to the acquisition
            % duration
            
            % Want any listeners on XSpan set to get called
            %if self.IsXSpanSlavedToAcquistionDuration ,
            for idx = 1:numel(self.PlotModels) ,
                self.PlotModels_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
            end
            self.broadcast('UpdateXSpan');
            %end    
            %self.XSpan = nan;
        end
        
        function didSetSweepDurationIfFinite(self)
            % Called by the parent to notify of a change to the acquisition
            % duration
            
            % Want any listeners on XSpan set to get called
            %if self.IsXSpanSlavedToAcquistionDuration ,
            for idx = 1:numel(self.PlotModels) ,
                self.PlotModels_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
            end
            self.broadcast('UpdateXSpan');
            %end    
            %self.XSpan = nan;
        end
        
        function out = get.NPlots(self)
            out = length(self.PlotModels);
        end
                
%         % Need to override the decodeProperties() method supplied by
%         % ws.Coding() to get correct behavior when the number of
%         % scopes changes.
%         function decodeProperties(self, propSet)
%             % Sets the properties in self to the values encoded in propSet.
%             % Returns the _old_ property values from self in
%             % originalValues.
%             
%             assert(isstruct(propSet));
%             
%             % Need to clear the existing scopes first
%             self.removeScopes_();
%             
%             % Now call the superclass method
%             %originalValues=self.decodeProperties@ws.Coding(propSet);  % not _really_ the originalValues, but I don't think it matters...
%             self.decodeProperties@ws.Coding(propSet);  % not _really_ the originalValues, but I don't think it matters...
% 
%             % Update the view
%             self.broadcast('Update');
%         end  % function
        
%         function didSetScopeIsVisibleWhenDisplayEnabled(self)
%             %self.broadcast('DidSetScopeIsVisibleWhenDisplayEnabled');
%         end
    end  % pulic methods block
    
%     methods (Access = protected)        
%         % Need to override the decodeUnwrappedEncodingCore_() method supplied
%         % by ws.Coding() to get correct behavior when the number of
%         % scopes changes.
%         function decodeUnwrappedEncodingCore_(self, encoding)            
%             % Need to clear the existing scopes first
%             self.removeScopes_();
%             
%             % Now call the superclass method
%             self.decodeUnwrappedEncodingCore_@ws.Coding(encoding);
% 
%             % Update the view
%             %self.broadcast('Update');  % do I need this?
%         end  % function        
%     end  % protected methods block
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)            
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function        
    end  % protected methods
    
%     methods (Static=true)
%         function tag=tagFromString(str)
%             % Transform an arbitrary ASCII string into a tag, which must be
%             % a valid Matlab identifier            
%             if isempty(str) ,
%                 tag=str;  % maybe should throw error, but they'll find out soon enough...
%                 return
%             end
%             
%             % Replace illegal chars with underscores
%             isAlphanumeric=isstrprop(str,'alphanum');
%             isUnderscore=(str=='_');
%             isIllegal= ~isAlphanumeric & ~isUnderscore;
%             temp=str;
%             temp(isIllegal)='_';
%             
%             % If first char is not alphabetic, replace with 'a'
%             isFirstCharAlphabetic=isstrprop(temp(1),'alpha');
%             if ~isFirstCharAlphabetic, 
%                 temp(1)='a';
%             end
%             
%             % Return the tag
%             tag=temp;
%         end  % function
%     end
    
%     methods
%         function mimic(self, other)
%             % Cause self to resemble other.
%             
%             % Get the list of property names for this file type
%             propertyNames = self.listPropertiesForPersistence();
%             
%             % Set each property to the corresponding one
%             for i = 1:length(propertyNames) ,
%                 thisPropertyName=propertyNames{i};
%                 if any(strcmp(thisPropertyName,{'PlotModels_'})) ,
%                     source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
%                     target = ws.Coding.copyCellArrayOfHandlesGivenParent(source,self) ;
%                     self.(thisPropertyName) = target ;
%                 else
%                     if isprop(other,thisPropertyName) ,
%                         source = other.getPropertyValue_(thisPropertyName) ;
%                         self.setPropertyValue_(thisPropertyName, source) ;
%                     end
%                 end
%             end
%         end  % function
%     end  % public methods block
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct() ;
%         mdlHeaderExcludeProps = {};
%     end
        
end
