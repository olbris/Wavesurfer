function dataFileAsStruct = loadDataFile(filename, formatString, tMin, tMax, minSweepIndex, maxSweepIndex)    
    % loadDataFile Loads WaveSurfer data into Matlab.
    % 
    %   loadDataFile(filename) 
    %       Loads the indicated WaveSurfer .h5 file.  The returned data is a
    %       structure array with one element per sweep in the data file.
    %
    %   loadDataFile(filename, formatString) 
    %       Returns the sweeps in a format indicated by formatString, which can
    %       be 'double' (the default), 'single', or 'raw'.  'double' yields
    %       scaled double-precision floats, 'single' yields scaled
    %       single-precision floats, and 'raw' returns unscaled ADC counts as 
    %       int16 values.  Note well: these raw ADC counts cannot be converted to
    %       double values by simply rescaling to the min and max of their
    %       range.  They must be passed through a cubic polynomial, as is done
    %       by ws.scaledDoubleAnalogDataFromRaw().
    %
    %   loadDataFile(filename, formatString, tMin, tMax) 
    %       Limits each returned sweep to samples in the time range
    %       tMin <= t < tMax, with times in seconds from the time of the first
    %       sample in each sweep.
    %
    %   loadDataFile(filename, formatString, tMin, tMax, minSweepIndex, maxSweepIndex)
    %       Limits the sweeps returned to those between minSweepIndex and
    %       maxSweepIndex, inclusive.
    
    % Deal with optional args
    if ~exist('formatString','var') || isempty(formatString) ,
        formatString = 'double';
    end
    if ~exist('tMin','var') || isempty(tMin) ,
        tMin = 0 ;  % in seconds
    end
    if ~exist('tMax','var') || isempty(tMax) ,
        tMax = inf ;  % in seconds
    end
    if ~exist('minSweepIndex', 'var') || isempty(minSweepIndex) ,
        minSweepIndex = -inf ;
    end   
    if ~exist('maxSweepIndex', 'var') || isempty(maxSweepIndex) ,
        maxSweepIndex = +inf ;
    end   
    
    % Process args
    if ~isfinite(tMax) && tMin~=0 ,
        error('If tMax is infinite, tMin must be equal to 0') ;
    end
    do_subset_in_time = isscalar(tMin) && isscalar(tMax) && isfinite(tMin) && isfinite(tMax) ;   
    
    % Check that file exists
    if ~exist(filename, 'file') , 
        error('The file %s does not exist.', filename)
    end
    
    % Check that file has proper extension
    [~, ~, ext] = fileparts(filename);
    if ~isequal(ext, '.h5') ,
        error('File must be a WaveSurfer-generated HDF5 (.h5) file.');
    end

    if do_subset_in_time ,
        % Read the sampling rate, so we can convert the tMin and tMax to a start
        % and a count
        try
            sampleRate = h5read(filename, '/header/AcquisitionSampleRate') ;
        catch me
            if isequal(me.identifier, 'MATLAB:imagesci:h5read:libraryError') ,
                sampleRate = h5read(filename, '/header/Acquisition/SampleRate') ;
            else
                rethrow(me) ;
            end               
        end
        firstScanIndex = round(tMin*sampleRate + 1) ;  % this is a one-based index
        scanCount = round((tMax-tMin)*sampleRate) ;
    else
        firstScanIndex = [] ;
        scanCount = [] ;
    end
    
    % Extract dataset at each group level, recursively.    
    dataFileAsStruct = crawl_h5_tree('/', filename, do_subset_in_time, firstScanIndex, scanCount, minSweepIndex, maxSweepIndex);
    
    % Correct the samples rates for files that were generated by versions
    % of WS which didn't coerce the sampling rate to an allowed rate.
    if isfield(dataFileAsStruct.header, 'VersionString') ,
        versionString = dataFileAsStruct.header.VersionString ;
        version = ws.scalarVersionFromVersionString(versionString) ;
    else
        % If no VersionsString field, the file is from an old old version
        version = 0 ;
    end
    if version<0.9125 ,  % version 0.912 has the problem, version 0.913 does not
        % Fix the acquisition sample rate, if needed
        nominalAcquisitionSampleRate = dataFileAsStruct.header.Acquisition.SampleRate ;
        nominalNTimebaseTicksPerSample = 100e6/nominalAcquisitionSampleRate ;
        if nominalNTimebaseTicksPerSample == round(nominalNTimebaseTicksPerSample) ,
            % nothing to do, so don't mess with the nominal value
        else
            actualAcquisitionSampleRate = 100e6/floor(nominalNTimebaseTicksPerSample) ;  % sic: the boards floor() for acq, but round() for stim
            dataFileAsStruct.header.Acquisition.SampleRate = actualAcquisitionSampleRate ;
        end
        % Fix the stimulation sample rate, if needed
        nominalStimulationSampleRate = dataFileAsStruct.header.Stimulation.SampleRate ;
        nominalNTimebaseTicksPerSample = 100e6/nominalStimulationSampleRate ;
        if nominalNTimebaseTicksPerSample == round(nominalNTimebaseTicksPerSample) ,
            % nothing to do, so don't mess with the nominal value
        else
            actualStimulationSampleRate = 100e6/round(nominalNTimebaseTicksPerSample) ;  % sic: the boards floor() for acq, but round() for stim
            dataFileAsStruct.header.Stimulation.SampleRate = actualStimulationSampleRate ;
        end
    else
        % data file is recent enough that there's no problem
    end
    
    %
    % If needed, use the analog scaling coefficients and scales to convert the    
    % analog scans from counts to experimental units.
    %
    
    if strcmpi(formatString,'raw') ,
        % User wants raw data, so nothing more to do
        return
    end
    
    % Figure out how many AI channels
    try
        if isfield(dataFileAsStruct.header, 'NAIChannels') ,
            % Newer files have this field, and lack dataFileAsStruct.header.Acquisition.NAnalogChannels
            nAIChannels = dataFileAsStruct.header.NAIChannels ;
        else
            % Fallback for older files
            nAIChannels = dataFileAsStruct.header.Acquisition.NAnalogChannels ;            
        end
    catch
        error('Unable to read number of AI channels from file.');
    end
    if nAIChannels==0 ,
         % There are no AI channels, so nothing more to do
        return
    end
    
    % If get here, need to do some non-trivial AI signal scaling, so get
    % scaling info
    try
        if isfield(dataFileAsStruct.header, 'AIChannelScales') ,
            % Newer files have this field, and lack dataFileAsStruct.header.Acquisition.AnalogChannelScales
            allAnalogChannelScales = dataFileAsStruct.header.AIChannelScales ;
        else
            % Fallback for older files
            allAnalogChannelScales=dataFileAsStruct.header.Acquisition.AnalogChannelScales ;
        end
    catch
        error('Unable to read channel scale information from file.');
    end
    
    try
        if isfield(dataFileAsStruct.header, 'IsAIChannelActive') ,
            % Newer files have this field, and lack dataFileAsStruct.header.Acquisition.AnalogChannelScales
            isActive = logical(dataFileAsStruct.header.IsAIChannelActive) ;
        else
            % Fallback for older files
            isActive = logical(dataFileAsStruct.header.Acquisition.IsAnalogChannelActive) ;
        end
    catch
        error('Unable to read active/inactive channel information from file.');
    end
    analogChannelScales = allAnalogChannelScales(isActive) ;

    % read the scaling coefficients
    try
        if isfield(dataFileAsStruct.header, 'AIScalingCoefficients') ,
            analogScalingCoefficients = dataFileAsStruct.header.AIScalingCoefficients ;
        else
            analogScalingCoefficients = dataFileAsStruct.header.Acquisition.AnalogScalingCoefficients ;
        end
    catch
        error('Unable to read channel scaling coefficients from file.');
    end

    % Actually scale the AI signals
    doesUserWantSingle = strcmpi(formatString,'single') ;
    fieldNames = fieldnames(dataFileAsStruct);
    for i=1:length(fieldNames) ,
        fieldName = fieldNames{i};
        if length(fieldName)>=5 && (isequal(fieldName(1:5),'sweep') || isequal(fieldName(1:5),'trial')) ,  
            % We check for "trial" for backward-compatibility with
            % data files produced by older versions of WS.
            analogDataAsCounts = dataFileAsStruct.(fieldName).analogScans;
            if doesUserWantSingle ,
                scaledAnalogData = ws.scaledSingleAnalogDataFromRaw(analogDataAsCounts, analogChannelScales, analogScalingCoefficients) ;
            else
                if ispc() ,
                    scaledAnalogData = ws.scaledDoubleAnalogDataFromRawMex(analogDataAsCounts, analogChannelScales, analogScalingCoefficients) ;
                else
                    scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(analogDataAsCounts, analogChannelScales, analogScalingCoefficients) ;
                end                    
            end
            dataFileAsStruct.(fieldName).analogScans = scaledAnalogData ;
        end
    end
    
end  % function



% ------------------------------------------------------------------------------
% crawl_h5_tree
% ------------------------------------------------------------------------------
function s = crawl_h5_tree(pathToGroup, filename, do_subset_in_time, firstScanIndex, scanCount, minSweepIndex, maxSweepIndex)
    % Get the dataset and subgroup names in the current group
    [datasetNames,subGroupNames] = get_group_info(pathToGroup, filename);
        
    % Create an empty scalar struct
    s=struct();

    % Add a field for each of the subgroups
    for idx = 1:length(subGroupNames)
        subGroupName=subGroupNames{idx};
        if ismember(1, strfind(subGroupName, 'sweep_')) ,
            % sweep subgroups get special treatment, and may get ignored
            sweepIndexAsString = subGroupName(7:end) ;
            sweepIndex = str2double(sweepIndexAsString) ;
            if minSweepIndex <= sweepIndex && sweepIndex <= maxSweepIndex ,                
                fieldName = field_name_from_hdf_name(subGroupName);
                pathToSubgroup = sprintf('%s%s/',pathToGroup,subGroupName);
                s.(fieldName) = crawl_h5_tree(pathToSubgroup, filename, do_subset_in_time, firstScanIndex, scanCount, minSweepIndex, maxSweepIndex);
            end
        else
            % non-sweep groups get recursed into, always
            fieldName = field_name_from_hdf_name(subGroupName);
            pathToSubgroup = sprintf('%s%s/',pathToGroup,subGroupName);
            s.(fieldName) = crawl_h5_tree(pathToSubgroup, filename, do_subset_in_time, firstScanIndex, scanCount, minSweepIndex, maxSweepIndex);
        end            
    end
    
    % Add a field for each of the datasets
    for idx = 1:length(datasetNames) ,
        datasetName = datasetNames{idx} ;
        pathToDataset = sprintf('%s%s',pathToGroup,datasetName) ;
        if isequal(datasetName, 'analogScans') || isequal(datasetName, 'digitalScans') ,
            if do_subset_in_time ,
                info = h5info(filename, pathToDataset) ;
                dataSize = info.Dataspace.Size ;
                if length(dataSize) < 2 ,
                    channelCount = 1 ;
                else
                    channelCount = info.Dataspace.Size(2) ;
                end
                dataset = h5read(filename, pathToDataset, [firstScanIndex 1], [scanCount channelCount], [1 1]) ;
            else
                dataset = h5read(filename, pathToDataset) ;
            end                
        else
            dataset = h5read(filename, pathToDataset) ;
        end            
        % Unbox scalar cellstr's
        if iscellstr(dataset) && isscalar(dataset) ,
            dataset=dataset{1};
        end
        fieldName = field_name_from_hdf_name(datasetName) ;        
        s.(fieldName) = dataset;
    end
end  % function



% ------------------------------------------------------------------------------
% get_group_info
% ------------------------------------------------------------------------------
function [datasetNames, subGroupNames] = get_group_info(pathToGroup, filename)
    info = h5info(filename, pathToGroup);

    if isempty(info.Groups) ,
        subGroupNames = cell(1,0);
    else
        subGroupAbsoluteNames = {info.Groups.Name};
        subGroupNames = ...
            cellfun(@local_hdf_name_from_path,subGroupAbsoluteNames,'UniformOutput',false);
    end

    if isempty(info.Datasets) ,
        datasetNames = cell(1,0);
    else
        datasetNames = {info.Datasets.Name};
    end
end  % function



% % ------------------------------------------------------------------------------
% % add_group_data
% % ------------------------------------------------------------------------------
% function s = add_group_data(pathToGroup, datasetNames, filename, sSoFar)
%     elementsOfPathToGroupRawSingleton = textscan(pathToGroup, '%s', 'Delimiter', '/');
%     elementsOfPathToGroupRaw = elementsOfPathToGroupRawSingleton{1} ;
%     elementsOfPathToGroup = elementsOfPathToGroupRaw(2:end);  % first one is generally empty string
%     elementsOfPathToField = ...
%         cellfun(@field_name_from_hdf_name, elementsOfPathToGroup, 'UniformOutput', false);
% 
%     % Create structure to be "appended" to sSoFar
%     sToAppend = struct();
%     for idx = 1:length(datasetNames) ,
%         datasetName = datasetNames{idx};
%         sToAppend.(datasetName) = h5read(filename, [pathToGroup '/' datasetName]);
%     end
% 
%     % "Append" fields to main struct, in the right sub-field
%     if isempty(elementsOfPathToField) ,
%         s = sSoFar;
%     else
%         s = setfield(sSoFar, {1}, elementsOfPathToField{:}, {1}, sToAppend);
%     end
% end



% ------------------------------------------------------------------------------
% force_valid_fieldname
% ------------------------------------------------------------------------------
function fieldName = field_name_from_hdf_name(hdfName)
    numVal = str2double(hdfName);

    if isnan(numVal)
        % This is actually a good thing, b/c it means the groupName is not
        % simply a number, which would be an illegal field name
        fieldName = hdfName;
    else
        try
            validateattributes(numVal, {'numeric'}, {'integer' 'scalar'});
        catch me
            error('Unable to convert group name %s to a valid field name.', hdfName);
        end

        fieldName = ['n' hdfName];
    end
end  % function



% ------------------------------------------------------------------------------
% local_hdf_name_from_path
% ------------------------------------------------------------------------------
function localName = local_hdf_name_from_path(rawPath)
    if isempty(rawPath) ,
        localName = '';
    else
        if rawPath(end)=='/' ,
            path=rawPath(1:end-1);
        else
            path=rawPath;
        end
        indicesOfSlashes=find(path=='/');
        if isempty(indicesOfSlashes) ,
            localName = path;
        else
            indexOfLastSlash=indicesOfSlashes(end);
            if indexOfLastSlash<length(path) ,
                localName = path(indexOfLastSlash+1:end);
            else
                localName = '';
            end
        end
    end
end  % function
