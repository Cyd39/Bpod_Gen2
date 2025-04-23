function NeuroPassiveFcns(action,hApp,~)

persistent RP zBus

switch action

    case 'PlotStimulus'
        Fs = 1/5.12e-6; %Hz sampling frequency 
        Par = getparams(hApp);
        SomDurs	    =	str2double(Par.SomatosensoryStimTime); % ms
        SomFreqs    =   str2num(Par.SomatosensoryFrequency,Evaluation='restricted'); %#ok<ST2NM> % Hz
        ISI		    =	str2double(Par.SomatosensoryISI);  % ms
        Amplitudes	=	str2num(Par.SomatosensoryAmplitude,Evaluation='restricted'); %#ok<ST2NM> % V 
        Waveform	=	Par.SomatosensoryWaveform; % 'Square','UniSine','BiSine'
        Offset	    =	str2double(Par.SomatosensoryOffset); 
        Ramp	    =	str2double(Par.SomatosensoryRamp); 
        
        % TODO: smart selection for display of multiple stimuli 
        % --- select single stimuli ---
        StimDur = max(SomDurs); % maximum duration
        SomFreq = SomFreqs(1);  % first frequency
        Amplitude = max(Amplitudes); % maximum amplitude
        % -------------------------

        % generate waveform
        [wv,tt] = gensomwaveform(Waveform,StimDur,Amplitude,SomFreq,Ramp,Fs);

        % padding pre-post stimulus time with zeroes
        PrePostDur = 0.2 * ISI * 0.001;
        PrePostSamp = round(PrePostDur * Fs);
        tt = [  -flip(1:PrePostSamp)./Fs,...
                tt,...
                tt(end) + (1:PrePostSamp)./Fs ];
        wv = [zeros(1,PrePostSamp), wv, zeros(1,PrePostSamp)];

        % plotting the waveform
        plot(hApp.StimDisplayAxes,tt,wv+Offset);
        xlim(hApp.StimDisplayAxes,[min(tt),max(tt)]);

    case 'Silence'
        Par.Rec = 'SIL';
        Par.MouseNum = str2double(hApp.MouseNumField.Value);
        Par.Set = hApp.SetField.Value;
        Stm = table;
        Sname		=	[hApp.SavePathField.Value '\M' num2str(Par.MouseNum) '_S' num2str(eval((Par.Set)),'%02u') '_' Par.Rec '.mat'];
        save(Sname,'Stm','Par');
        
        for k=1:3
            beep
            pause(.4)
        end
        
    case 'Init'
        hApp.Gauge.Value = 0;
        %-- Stimulation --%
        
        RCOname		=	hApp.RCOName;
        disp('Loading TDT circuit...');
        [zBus,RP]	=	setuptdt(RCOname);
        
        hApp.zBus	=	zBus;
        hApp.RP     =	RP;
        
        rng('shuffle'); % initialize RNG with current clock
        
    case 'SavePar'
        
        Par         =	getguifields(hApp);
        saveName    =   ['NP_Params_', datestr(datetime('now'),'yyyy-mm-dd'), '.mat'];
        uisave('Par',saveName); 

    case 'LoadPar'
        
        [fn, pn, ~] = uigetfile('NP_Params_*.mat','Select parameter file to load');
        fullFN = [pn fn];
        vars = who('-file', fullFN);
        if(ismember('Par', vars))
            load(fullFN,'-mat','Par');
            setguifields(hApp,Par);
            hApp.CarrierTypeChanged();
            setRecType(hApp,Par.Rec,1);
        else
            disp('Parameters not found in file!');
        end

    case 'Est'
        
        Par			=	getparams(hApp);
        
        estimatedur(hApp,Par);
        
    case 'Run'
        
        RS		=	RP{1,1};	%-- Stimulation real-time processor --%

        %-- Get parameters and do some calculations --%
        Par			=	getparams(hApp); % get parameters from GUI
        StmType     =   Par.Rec;  %-- Get the current stimulus type --%
        Ntrl		=	Par.Ntrl;
        Par.Fs_stm	=	RS.GetSFreq;
        
        % --- setup pre-, stim-, post- recording times based on stimulus type ---
        contStim    =   0;
        multiStim   =   0;
        switch StmType
            case {'FRA'}
                PreTime		=	str2double(Par.FRAPreTime);
                StimTime	=	str2double(Par.FRAStimTime);
                PostTime	=	str2double(Par.FRAPostTime);
            case {'AM1','AM2','AM','AMn','AMtest'}
                PreTime		=	str2double(Par.AMPreTime);
                StimTime	=	str2double(Par.AMStimTime);
                PostTime	=	str2double(Par.AMPostTime);
            case {'FM'}
                PreTime		=	str2double(Par.FMPreTime);
                StimTime	=	str2double(Par.FMStimTime);
                PostTime	=	str2double(Par.FMPostTime);
            case {'DRC'}
                contStim = 1;
                multiStim = 1;
                PreTime = 0;
                StimTime = 0; 
                ostTime = 0;
            case {'OMI'}
                PreTime = 0; StimTime = 0; PostTime = 0;
            case {'CI'}
                PreTime     =   str2double(Par.CIPreTime);
                StimTime    =   str2double(Par.CIStimTime);
                PostTime    =   str2double(Par.CIPostTime);
            case {'Opt','OptoFRA'}
                PreTime     =   str2double(Par.FRAPreTime);
                StimTime    =   str2double(Par.FRAStimTime);
                PostTime    =   str2double(Par.FRAPostTime);
            case {'SOM','SxA'}
                PreTime     =   20; %ms
                StimTime    =   str2double(Par.SomatosensoryStimTime);
                PostTime    =   100;  %ms
                Aud       =   [];
            otherwise
                PreTime = 0; StimTime = 0; PostTime = 0;
        end
        
        RecDur		=	PreTime + StimTime + PostTime;
        % -----------------------------------------------
        
        %-- Start real-time stimulation & recording processors --%
        zBus.zBusTrigA(0,2,3);zBus.zBusTrigB(0,2,3); % reset zBus
        RS.Run;
        
        %-- Set TDT general tags --%
        RS.SetTagVal('PreRecDur',PreTime);
        if ismember(StmType,{'SOM','SxA'})
            Offset	    =	str2double(Par.SomatosensoryOffset); 
            RS.SetTagVal('SomOffset',Offset);
        end
        
        %-- Create folder & file name for saving --%
        Sname		=	[Par.SavePath '\M' num2str(Par.MouseNum) '_S' num2str(eval(Par.Set),'%02u') '_' StmType '.mat'];
        
        %-- Check if data folder exists. If not: create it. --%
        if( exist(Par.SavePath,'file') ~= 7 )
            mkdir(Par.SavePath);
        end
        
        %-- Check if filename already exists --%
        if( exist(Sname,'file') == 2 )
            Options.Interpreter	=	'tex';
            Options.Default		=	'no';
            Qdlg				=	questdlg([{	'Filename does already exist.'};{'Continue anyway?'}], ...
                'Check filename','yes','no',Options);
            
            if( strcmpi(Qdlg,'no') )
                hApp.STARTButton.Value = 0;
            else
                delete(Sname);
            end
        end
                      
        %-- Initialize data structure --%
        Stm             =	Par.Stm;
        Stm.TrigTime    =   NaT(Ntrl,1);
        Stm.TrialTime   =   NaT(Ntrl,1);
        
        %-- Start timer --%
        TrialTime	=	nan(Ntrl,1);
        
        Tstart		=	tic;


        % -- Remote communications ---
            % Open Ephys GUI
            msg = ['start s',Par.Set];
            msgOpenEphys(msg);
        % ----------------------------
        
        if(multiStim)
            NRep = Ntrl;
        else
            NRep = 1;
        end
        %*************-START OF MAIN PRESENTATION LOOP-**********************%
        for k = 1:NRep:Ntrl
            Ttrial	=	tic;
            
            %-- User stopped the set --%
            if( hApp.STARTButton.Value == 0 )
                break
            end
            
            % 			%-- User paused the set --%
            while( hApp.PAUSEButton.Value == 1 )
                pause(0.01)
            end
            %-- Set stimulus specific tags --%
            
            switch Par.Rec
                case {'FRA'}
                    if( ~setfratrial(hApp,RP{1,1},Par,k))%,RecDur) )
                        error('Unable to initialize FRA trial.')
                    end
                    
                case {'AM1','AM2','AMn'}
                    if( ~setamtrial(hApp,RP{1,1},Par,k))%,RecDur) )
                        error('Unable to initialize AM trial.')
                    end
                   
                case {'DRC'} 
                    [Snd,Pul] = setDRCtrial(hApp,RS,Par,k);
                    
                case {'OMI'}
                    [Out,Par.Stm.RandomState{k}] = setomitrial(hApp,RP{1,1},Par,k);
                    if(~Out)
                        error('Unable to initialize Omission trial.')
                    end
                case {'Opt','OptoFRA'}
                    if( ~setoptotrial(hApp,RP{1,1},Par,k))
                        error('Unable to initialize Opt trial.')
                    end     
                case {'CI'}
                    if( ~setcitrial(hApp,RP{1,1},Par,k))%,RecDur) )
                        error('Unable to initialize CI trial.')
                    end
                case {'FM'}
                    if( ~setfmtrial(hApp,RP{1,1},Par,k,RecDur) )
                        error('Unable to initialize FM trial.')
                    end
                    
                case {'AMtest'}
                    if( ~setamttrial(hApp,RP{1,1},Par,k,RecDur) )
                        error('Unable to initialize AMtest trial.')
                    end
                case {'SOM'}
                    if( ~setsomtrial(hApp,RP{1,1},Par,k,RecDur) )
                        error('Unable to initialize SOM trial.')
                    end
                case {'SxA'}
                    if( ~setsomaudtrial(hApp,RP{1,1},Par,k,PreTime,PostTime) )
                        error('Unable to initialize SxA trial.')
                    end
            end
            
            
            if contStim % continuous stimuli
                [Stm.TrigTime(k+(1:NRep)-1), Stm.TrialTime(k+(1:NRep)-1),terminated]...
                    = contPlay(hApp,Snd,Pul,NRep,round(5*Par.Fs_stm));
                if (terminated)
                    disp('Terminated');
                end
            else % single trial stimulus
                
                % ISI wait for duration
                if ismember(StmType,{'SOM','SxA'}) && k > 1
                    if strcmp(StmType,'SxA')
                        StimDur = max(Stm.SomDur(k-1),Stm.AudDur(k-1)); %not necessarily correct...
                    else
                        StimDur = Stm.SomDur(k-1);
                    end
                    while (datetime('now') - Stm.TrigTime(k-1)) < ...
                            milliseconds(Stm.ISI(k-1) + StimDur) 
                        pause(0.01);
                    end
                end

                zBus.zBusTrigB(0,0,3);          %-- Triggering

                 %-- Save stimulus settings of current trial --%
                Stm.TrigTime(k)     =	datetime('now');                     
                %-- Wait during stimulus presentation & recording --%
                while( RS.GetTagVal('Active') == 1 )
                    %             while( RS.GetTagVal('Active') == 1 || RR.GetTagVal('Active') == 1 )
                    pause(0.01)
                end

                %-- Save stimulus settings of current trial --%
                Stm.TrialTime(k)	=	datetime('now');    
                
                                %-- Update remaining time --%
                TrialTime(k,1)						=	toc(Ttrial);
                TimeLeft							=	round( ( nanmean(TrialTime)*Ntrl - nanmean(TrialTime)*k ) / 60, 2 );
                hApp.StimulusNumArea.Text			= {[num2str(Ntrl-k) ' stimuli left']};
                if( TimeLeft <= 1 )
                    TimeLeft						=	round( ( nanmean(TrialTime)*Ntrl - nanmean(TrialTime)*k ), 1 );
                    hApp.DurationTextArea.Text		=	{[num2str(TimeLeft) ' sec left']};
                else
                    hApp.DurationTextArea.Text		=	{[num2str(TimeLeft) ' min left']};
                end
                PercComplete						=	(k/Ntrl)*100;
                hApp.Gauge.Value					=	PercComplete;
                
                % --- SOM read aud recording --
                if ismember(StmType,{'SOM','SxA'})
                    try
                        TotalDurSamp = RS.GetTagVal('TotalDurSamp');
                        AudIn = RS.ReadTagV('DataOut', 0, TotalDurSamp);
                        tt = (1:length(AudIn)) ./ Par.Fs_stm - PreTime*0.001;
                        plot(hApp.StimDisplayAxes,tt,AudIn);
                        if(k == 1);xlim(hApp.StimDisplayAxes,[min(tt),max(tt)]);end
                        Aud{k} = AudIn;
                        % disp('Reading ADC ok.')
                        % keyboard
                    catch
                        disp('error reading ADC.')
                    end
                end
                % -----------------------------
                
                % --- FRA Online Analysis ---
                if mod(k,Par.NUStim)== 0 && strcmp(Par.Rec,'FRA')
%                 if strcmp(Par.Rec,'FRA')
                   try
                        FRA = FRAOnline(hApp,Par); 
                   catch MExc
                        disp('Error in FRA online analysis.');
                        disp(getReport(MExc));
                   end
                end
                % ---- END OF FRA Online Analysis --------
            end
         
        end
        %*************-END OF MAIN PRESENTATION LOOP-**********************%

        % -- Remote communications ---
            % Open Ephys GUI
            msg = ['end s',Par.Set];
            msgOpenEphys(msg);
        % ----------------------------

        % ********** SAVE DATA after everything *************
        if strcmp(Par.Rec,'FRA') % saving FRA online analysis
            try
                save(Sname,'Stm','Par','FRA');
            catch
                save(Sname,'Stm','Par')
            end
            if ishandle(hApp.hOA) % check and save online analysis graph
                try
                    Fname = replace(Sname,'.mat','.fig');
                    saveas(hApp.hOA,Fname);
                    disp('FRA Online Analysis saved.')
                catch
                    disp('ERROR: FRA Online Analysis NOT saved.')
                end
            end
        else % default data saving
            save(Sname,'Stm','Par')
        end

        % --- saving sound recording ----
        if ismember(Par.Rec,{'SOM','SxA'})
            try
                Fs      = Par.Fs_stm;
                Sndname = replace(Sname,'.mat','_Sound.mat');
                save(Sndname,"Aud","Fs");
            catch
                disp('ERROR: Sound recording NOT saved.')
            end
        end
        % -------------------------------

        Tblname = replace(Sname,'.mat','_Stm.csv');
        writetable(Stm,Tblname);
        % ********* END OF SAVE DATA after everything ***********
        
        hApp.STARTButton.Value = 0;
        
        %-- User feedback --%
        for k=1:3
            beep
            pause(.4)
        end
        
        NeuroPassiveFcns('Halt',hApp);
        
        Tstop	=	round(toc(Tstart)/60);
        disp(['the program ran for ' num2str(Tstop) ' min'])
        
        
    case 'Halt'
        
        RS	=	RP{1,1};	%-- Stimulation real-time processor --%
        % 		RR	=	RP{2,1};	%-- Recording real-time processor	--%
        
        %-- Wait during stimulus presentation & recording --%
        while( RS.GetTagVal('Active') == 1)
            pause(0.01)
        end
        
        zBus.zBusTrigA(0,2,3);
              
        RS.Halt;
        
        Status	=	double(RS.GetStatus);	%-- Gets status of stimulation device		--%
        if bitget(Status,3) == 0			%-- Checks for errors in running circuit	--%
            disp('Stimulation circuit halted');
        else
            disp('Error halting stimulation circuit');
        end
        
        % --- Reset GUI to initial state ---
        hApp.STARTButton.Text = "START";
        hApp.STARTButton.BackgroundColor = [0 1 0];
        hApp.InjectionCheckBox.Value = 0;
        hApp.FRAButton.Enable = 'on';
        hApp.AMButton.Enable = 'on';
        hApp.FMButton.Enable = 'on';
        hApp.STRFButton.Enable = 'on';
        hApp.OMIButton.Enable = 'on'; 
        hApp.CIButton.Enable = 'on';
        hApp.OptoButton.Enable = 'on';
        hApp.SOMButton.Enable = 'on';
        hApp.FRAButton.Value = 0;
        hApp.AMButton.Value = 0;
        hApp.FMButton.Value = 0;
        hApp.STRFButton.Value = 0;
        hApp.OMIButton.Value = 0;
        hApp.CIButton.Value = 0;
        hApp.OptoButton.Value = 0;
        hApp.SOMButton.Value = 0;
        hApp.TabGroup.Visible = 'off';
        hApp.TrialInformationPanel.Visible = 'off';
        hApp.STARTButton.Visible = 'off';
        hApp.PAUSEButton.Visible = 'off';
        % --- END OF Reset GUI to initial state ---
        
end


%--Local Functions--%
function Par = getparams(hApp)

    Par = getguifields(hApp); % -- get settings from GUI
    
    % -- create Stm table --
    switch Par.Rec
        case {'FRA'}
            Stm     =   makefrastm(Par);
        case {'AM1','AM2'}
            Stm     =   makeAMstm(Par);
        case {'AMn'}
            Stm     =   makeAMnoisestm(Par);
        case {'DRC'}
            Stm     =   makeDRCstm(Par);
        case {'OMI'}
            Stm     =   makeomistm(Par);
        case {'CI'}
            sNotch  =   hApp.CINotchCheckBox.Value;
            Stm     =   makeCIstm(Par);
        case {'Opt','OptoFRA'}
            Stm     =   makeoptostm(Par);
        case {'SOM'}
            Stm     =   makesomstm(Par);
        case {'SxA'}
            Stm     =   makeSomAudStm(Par);
        % --- OLD ---
        case {'FM'} % to be converted to Stm
            StmMtx	=	makefmtrl(Par);
            Dur		=	unique(StmMtx(:,5));
            hApp.FMStimTimeField.Value = num2str(Dur);

        case {'AMtest'} % to be converted to Stm
            Par.StmSel=   [hApp.RipCheckBox.Value, hApp.BBCheckBox.Value, hApp.NBCheckBox.Value];
            StmMtx  =   makeAMtesttrl(Par);
        % ----------
    end
    Par.Stm     =	Stm;
    Par.Ntrl	=	size(Stm,1);
    Par.NUStim  =   sum(Stm.Rep == 1);
    % ------------------------
    
    % -- Load calibration --
    load(Par.CalibrationPath,'Gain','Ref');
    Par.Gain    = Gain;
    Par.Ref     = Ref;
    % ----------------------

function Par = getguifields(hApp)

Par			=	struct; % initialize Par
    
%-Get Recording Type-%
sFRA		=	hApp.FRAButton.Value; %FRA: tones
sAM			=	hApp.AMButton.Value;  %AM: amplitude-modulated multi-tone complex
sFM			=	hApp.FMButton.Value;  %FM: frequency-modulated tone sweep
sAMt		=	0;%hApp.AMtButton.Value; %AMt: amplitude-modulated sound with different carriers
sDRC		=	hApp.STRFButton.Value; %DRC: Dynamic Random Chord
sOmi		=	hApp.OMIButton.Value; %Omis: Omission paradigm
sCI         =   hApp.CIButton.Value; %CI: Continuity Illusion stimuli
sOpto       =   hApp.OptoButton.Value; %Opt: optogenetics stimuli
sOptoFRA    =   hApp.AddTonesCheckBox.Value; %AddTones: include sounds for 
sSOM        =   hApp.SOMButton.Value; %SOM: somatosensory stimuli


if sFRA == 1
	Par.Rec =	'FRA';
elseif sAM == 1
    switch hApp.CarrierTypeSwitch.Value
        case {'Noise'}
            Par.Rec = 'AMn';
        case {'Multitone'}
        if strcmp(hApp.AMTypeSwitch.Value,'AM1')
            Par.Rec =	'AM1';
        elseif strcmp(hApp.AMTypeSwitch.Value,'AM2')
            Par.Rec =	'AM2';
        end
        otherwise % random stuff
            Par.Rec = 'AM';
    end
elseif sFM == 1
	Par.Rec =	'FM';
elseif sAMt == 1
	Par.Rec =	'AMtest';
elseif sDRC
	Par.Rec =	'DRC';
elseif sOmi
	Par.Rec =	'OMI';
elseif sCI
	Par.Rec =	'CI';
elseif sOpto
    if (sOptoFRA)
        Par.Rec =	'OptoFRA';
    else
        Par.Rec =	'Opt';
    end
elseif sSOM == 1
    if hApp.SomatosensoryonlyButton.Value
        Par.Rec = 'SOM';
    elseif hApp.SomatosensoryAuditoryButton.Value
        Par.Rec = 'SxA';
    end
end

% -- whether injection has occurred --- (legacy: to be removed)
Par.InjIdx  =	hApp.InjectionCheckBox.Value;

% -- read in all fields --
Field	=	fields(hApp);

Nfield	=	size(Field,1);
	
for k=1:Nfield
	cF	=	Field{k,1};
	if length(cF) < 5
		continue
	else
		if(  contains(cF(end-4:end),'Field')  )
			%-- Variable name --%
			VarName	=	cF(1:end-5);
            Par.(VarName) = hApp.(cF).Value;
        elseif ( (length(cF) > 8) && contains(cF(end-7:end),'DropDown') )
            VarName	=	cF(1:end-8);
            Par.(VarName) = hApp.(cF).Value;
		end
	end
end

function setguifields(hApp,Par)
    
%-Set Recording Type-%

    % set all buttons to zero
    hApp.FRAButton.Value    = 0;
	hApp.AMButton.Value     = 0;  
	hApp.FMButton.Value     = 0;  
	hApp.STRFButton.Value   = 0; 
	hApp.OMIButton.Value    = 0;
    hApp.CIButton.Value     = 0;
    hApp.OptoButton.Value   = 0; 
    hApp.SOMButton.Value    = 0; 
    
    % set specific one buttons to 1

    switch Par.Rec
        case {'FRA'} %FRA: tones
            hApp.FRAButton.Value    = 1;
        case {'AM','AMtest'}
            hApp.AMButton.Value     = 1;  
        case {'AM1','AM2'} %AM: amplitude-modulated multi-tone complex
            hApp.AMButton.Value     = 1;  
            hApp.CarrierTypeSwitch.Value = 'Multitone';
        case {'AMn'}
            hApp.AMButton.Value     = 1;  
            hApp.CarrierTypeSwitch.Value = 'Noise';
        case {'DRC'} %DRC: Dynamic Random Chord
            hApp.STRFButton.Value   = 1; 
        case {'Omi','OMI'} %Omis: Omission paradigm
            hApp.OMIButton.Value    = 1; 
        case {'CI'}
            hApp.CIButton.Value     = 1;
        case {'Opt','OptoFRA'}
             hApp.OptoButton.Value  = 1; 
        case {'SOM', 'SxA'}
            hApp.SOMButton.Value    = 1; 
        % --- OLD ---
        case {'FM'} %FM: frequency-modulated tone sweep
            hApp.FMButton.Value     = 1;  
        % ----------
    end

% -- whether injection has occurred --- (legacy: to be removed)
if (isfield(Par,'InjIdx'))
	hApp.InjectionCheckBox.Value = Par.InjIdx;
end

% -- read in all fields --
Field	=	fields(Par);
Nfield	=	size(Field,1);
ExcVar  = { 'Rec', 'InjIdx',...
            'SavePath','CalibrationPath',...
            'MouseNum','Penetration','Set'};
for k=1:Nfield
	VarName     =	Field{k,1};
    if ismember(VarName,ExcVar); continue;end
    cF = [VarName, 'Field'];
    cF2 = [VarName, 'DropDown'];
    if (isprop(hApp,cF))
        hApp.(cF).Value = Par.(VarName);
    elseif (isprop(hApp,cF2))
        hApp.(cF2).Value = Par.(VarName);
    else
        disp(['Parameter ''' VarName ''' not loaded.']);
    end
end

function estimatedur(hApp,Par)

ISI = [];
PreTime = [];
StimTime = [];
PostTime = [];

if ( strcmpi(Par.Rec,'FRA') )
	ISI			=	str2double( Par.FRAISI );
	PreTime		=	str2double(Par.FRAPreTime);
	StimTime	=	str2double(Par.FRAStimTime);
	PostTime	=	str2double(Par.FRAPostTime);
elseif( strcmpi(Par.Rec,'AM1') || strcmpi(Par.Rec,'AM2') )
	ISI			=	str2double( Par.AMISI );
	PreTime		=	str2double(Par.AMPreTime);
	StimTime	=	str2double(Par.AMStimTime);
	PostTime	=	str2double(Par.AMPostTime);
elseif( strcmpi(Par.Rec,'FM') )
	ISI			=	str2double( Par.FMISI );
	PreTime		=	str2double(Par.FMPreTime);
	StimTime	=	str2double(hApp.FMStimTimeField.Value);
	PostTime	=	str2double(Par.FMPostTime);
elseif( strcmpi(Par.Rec,'AMtest') )
	ISI			=	str2double( Par.AMtISI );
	PreTime		=	str2double(Par.AMtPreTime);
	StimTime	=	str2double(Par.AMtStimTime);
	PostTime	=	str2double(Par.AMtPostTime);
elseif( strcmpi(Par.Rec,'CI') )
    ISI			=	str2double( Par.CIISI );
	PreTime		=	str2double(Par.CIPreTime);
	StimTime	=	str2double(Par.CIStimTime);
	PostTime	=	str2double(Par.CIPostTime);
elseif( strcmpi(Par.Rec, 'SOM') )
    ISI			=	str2double(Par.SomatosensoryISI);
	PreTime		=	0;
	StimTime	=	str2double(Par.SomatosensoryStimTime);
	PostTime	=	0;
end

Ntrl		=	Par.Ntrl;
%RecDur		=	Par.PreRec + max(Par.Dur)*Fac + Par.PostRec;
RecDur		=	PreTime + StimTime + PostTime;
TotalDur	=	ceil( ( RecDur + ISI ) * Ntrl / (1000*60) );
TotalDur	=	TotalDur + TotalDur*1.5;

hApp.StimulusNumArea.Text = [num2str(Ntrl) ' stimuli'];
hApp.DurationTextArea.Text = ['Estimated time: ' num2str(TotalDur) ' minutes'];


function FRA = makefratrl(Par)

Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);
Nrep	=	str2double(Par.FRARepetitions);
Dur		=	str2double(Par.FRAStimTime);
PreRec	=	str2double(Par.FRAPreTime);
PostRec	=	str2double(Par.FRAPostTime);
ISI		=	str2double(Par.FRAISI);
Spk		=	str2double(Par.FRALocation);
Level	=	eval(Par.FRALevel);
Freq	=	eval(Par.FRAFreqRange);
Oct		=	eval(Par.FRAOctStep);

if( Oct ~= 0 && length(Freq) > 1 )
	Freq	=	Freq(1) * 2.^(0:Oct:log2(Freq(2)/Freq(1)));
end

[F,L,S]	=	meshgrid(Freq,Level,Spk);
FLS		=	[F(:) L(:) S(:)];
Nfl		=	size(FLS,1);

%--					1					2					3					4					5					 6				 7		 8		 9	 10	--%
%--				Animal name			Set number			Penetration			Pre-Record			Duration			Post-Record			ISI		Freq	Lvl	Spk	--%
FRA		=	[repmat(Aname,Nfl,1) repmat(Nname,Nfl,1)   repmat(Pen,Nfl,1)   repmat(PreRec,Nfl,1) repmat(Dur,Nfl,1)  repmat(PostRec,Nfl,1) nan(Nfl,1)    FLS];

%-- Add control quiet condition --%
FRA		=	[FRA;
			Aname Nname Pen PreRec Dur PostRec NaN 1 NaN 1];

%-- Trial randomization --%
FRA		=	randtrls(FRA,Nrep);

%-- Add random inter-stimulus interval --%
ISIrnd	=	getisi(ISI,size(FRA,1));
FRA(:,7)=	ISIrnd;

function Aud = makestrftrl(Par)

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	--%

Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);

if (strcmpi(Par.Rec,'AM1')) || (strcmpi(Par.Rec,'AM2'))
	Dur		=	str2double(Par.AMStimTime);
	PreRec	=	str2double(Par.AMPreTime);
	PostRec	=	str2double(Par.AMPostTime);
	ISI		=	str2double(Par.AMISI);
	
	%-- Auditory parameters --%
	Sndloc	=	str2double(Par.AMLocation);
	Sndlvl	=	eval(Par.AMLevel);
	Sndvel	=	eval(Par.AMVelocity);
	Snddens	=	0;
	Sndmd	=	eval(Par.AMModDepth);
	F0		=	str2double(Par.AMF0);
	Nfreq	=	str2double(Par.AMNFreq);
	
	Nrep	=	str2double(Par.AMRepetitions);
	
elseif strcmpi(Par.Rec,'STRF')
	Dur		=	str2double(Par.STRFStimTime);
	PreRec	=	str2double(Par.STRFPreTime);
	PostRec	=	str2double(Par.STRFPostTime);
	ISI		=	str2double(Par.STRFISI);
	
	%-- Auditory parameters --%
	Sndloc	=	str2double(Par.STRFLocation);
	Sndlvl	=	str2double(Par.STRFLevel);
	Sndvel	=	eval(Par.STRFVelocity);
	Snddens	=	eval(Par.STRFDensity);
	Sndmd	=	eval(Par.STRFModDepth);
	F0		=	str2double(Par.STRFF0);
	Nfreq	=	str2double(Par.STRFNFreq);
	
	Nrep	=	str2double(Par.AMRepetitions);
end

%-- Unimodal auditory stimulus parameters --%
[V,D,M,S,L]	=	ndgrid(Sndvel',Snddens',Sndmd',Sndloc',Sndlvl');

V		=	V(:);
D		=	D(:);
M		=	M(:);
S		=	S(:);
L		=	L(:);
Aud		=	[V D M L S];

sel		=	Aud(:,3) == 0;                      %Selecting all non-unmodulated stimuli
Aud		=	Aud(~sel,:);                        %Unmodulated stimuli are removed from Aud

for k=1:length(Sndlvl)
Aud(end+1,:) = [NaN, 0, 0, Sndlvl(k), Sndloc];  %#ok<AGROW>
end

% Aud(end+1,:) = [NaN, 0, 0, Sndlvl, Sndloc];     %Single unmodulated stimulus is added to Aud

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	--%
Aud		=	[	repmat(Aname,size(Aud,1),1) repmat(Nname,size(Aud,1),1) repmat(Pen,size(Aud,1),1) ...
				repmat(PreRec,size(Aud,1),1) repmat(Dur,size(Aud,1),1) repmat(PostRec,size(Aud,1),1) nan(size(Aud,1),1) ...
				Aud repmat(F0,size(Aud,1),1) repmat(Nfreq,size(Aud,1),1)	];

%-- Trial randomization --%
Aud	=	randtrls(Aud,Nrep);

%-- Add random inter-stimulus interval --%
ISIrnd		=	getisi(ISI,size(Aud,1));
Aud(:,7)	=	ISIrnd;

function Drand = randtrls(D,Nrep)

rng('shuffle');

[Nstm,Ncol]		=	size(D);
if(istable(D))
    Drand           =   table;
else
    Drand			=	nan(Nstm*Nrep,Ncol+1);
end

start			=	1;
stop			=	start + Nstm - 1;

for k=1:Nrep
	Idx					=	randperm(Nstm);
    if(istable(D))
        D.Rep               =   repmat(k,Nstm,1);
        Drand(start:stop,:) =   D(Idx,:);
    else
        Drand(start:stop,:)	=	[D(Idx,:) repmat(k,Nstm,1)];
    end
    
    start				=	stop + 1;
	stop				=	start + Nstm - 1;
end

function ISIrnd = getisi(ISI,N)

[r,c]	=	size(ISI);
if( c > r )
	ISI	=	ISI';
end

Nisi	=	size(ISI,1);
Fac		=	ceil( N / Nisi );

ISI		=	ceil( repmat(ISI,Fac,1) );
ISI		=	ISI(1:N,1);
Idx		=	randperm(N);
ISIrnd	=	ISI(Idx,1);

function Out = setfratrial(hApp,RS,Par,k)%,RecDur)

%-- Load tone gain table --%
Gain		=	Par.Gain;
RefdB		=	Par.Ref(1,2);
DACmax		=	Par.Ref(1,3);

%-- Get parameters --%
Fs			=	Par.Fs_stm;
ISI			=	Par.Stm.ISI(k) * 1e-3; %ms -> s 
Freq		=	Par.Stm.Freq(k) * 1000; % kHz -> Hz
Lvl			=	Par.Stm.Intensity(k); % dB SPL
Spk			=	Par.Stm.Speaker(k); 
Dur			=	Par.Stm.StimT(k); % ms
PreT		=	Par.Stm.PreT(k); % ms
PostT       =	Par.Stm.PostT(k); % ms
RecDur      =   (PreT+Dur+PostT) * 1e-3; %ms -> s

sel			=	Gain(:,3) == Spk;		

Gain		=	Gain(sel,:);

Amp			=	getamp(Gain,Freq,Lvl,RefdB,DACmax);
ToneDur		=	Dur;
ToneSamp	=	round(ToneDur * Fs / 1000);

TotalDur	=	RecDur + ISI; %s
TotalSamp	=	round(TotalDur * Fs); %samp

RS.SetTagVal('Freq',Freq);
RS.SetTagVal('Amp',Amp);
RS.SetTagVal('ToneDur',ToneSamp);
RS.SetTagVal('TotalDur',TotalSamp);
% disp(['Freq = ' num2str(Freq) ' Hz']);

%-- Select speakers --%
Sstr 	=	setspeaker(Spk,RS);

% pause(0.05);

%-- Update stimulus info text --%
hApp.StimulusTextArea.Text = [ {['Frequency ' num2str(round(Freq/1000)) ' kHz']} ...
								 {['Level ' num2str(Lvl) ' dB SPL']} ...
								 {Sstr}	];

Out		=	1;


function Out = setoptotrial(hApp,RS,Par,k)%,RecDur)

%-- Load tone gain table --%
Gain		=	Par.Gain;
RefdB		=	Par.Ref(1,2);
DACmax		=	Par.Ref(1,3);

%-- Get parameters --%
Fs			=	Par.Fs_stm;
ISI			=	Par.Stm.ISI(k) * 1e-3; %ms -> s 
Freq		=	Par.Stm.Freq(k) * 1000; % kHz -> Hz
Lvl			=	Par.Stm.Intensity(k); % dB SPL
Spk			=	Par.Stm.Speaker(k); 
ToneDur		=	Par.Stm.ToneT(k); % ms
PreT		=	Par.Stm.PreT(k); % ms
PostT       =	Par.Stm.PostT(k); % ms
LEDDur		=	Par.Stm.LEDDur(k); % ms
LEDDelay	=	Par.Stm.LEDDelay(k); % ms
StimDur     =   (PreT+max([ToneDur,LEDDelay+LEDDur])+PostT) * 1e-3; %ms -> s

sel			=	Gain(:,3) == Spk;		

Gain		=	Gain(sel,:);

if Lvl == -Inf
    Amp = 0;
else
    Amp			=	getamp(Gain,Freq,Lvl,RefdB,DACmax);
end

ToneSamp	=	round(ToneDur * Fs / 1000);
LEDSamp     =	round(LEDDur * Fs / 1000);

TotalDur	=	StimDur + ISI; %s
TotalSamp	=	round(TotalDur * Fs ); %samp

RS.SetTagVal('Freq',Freq);
RS.SetTagVal('Amp',Amp);
RS.SetTagVal('ToneDur',ToneSamp);
RS.SetTagVal('TotalDur',TotalSamp);
RS.SetTagVal('LEDDur',LEDSamp);
RS.SetTagVal('LEDDelay',PreT+LEDDelay);

% disp(['Freq = ' num2str(Freq) ' Hz']);

%-- Select speakers --%
Sstr 	=	setspeaker(Spk,RS);

% pause(0.05);

%-- Update stimulus info text --%
hApp.StimulusTextArea.Text = [ {['Frequency ' num2str(round(Freq/1000)) ' kHz']} ...
								 {['Level ' num2str(Lvl) ' dB SPL']} ...
								 {['LED Dur ' num2str(LEDDur) ' ms']} ...
								 {Sstr}	];

Out		=	1;

function Out = setsomaudtrial(hApp,RS,Par,k,PreTime,PostTime)

%-- Get parameters --%
Fs			    =	Par.Fs_stm;
    % somatosensory
    SomDur		    =	Par.Stm.SomDur(k); %ms %[CHANGED]
    SomFreq         =   Par.Stm.SomFreq(k); % Hz
    Amplitude	    =	Par.Stm.Amplitude(k); % V
    Waveform        =   Par.Stm.Waveform(k);
    SomRamp            =   Par.Stm.SomRamp(k); % ms

    % sound
    AudStimType     =   Par.Stm.AudStimType(k);
    AudDur          =   Par.Stm.AudDur(k); %ms  %[NEW]
    AudIntensity    =	Par.Stm.AudIntensity(k); % dB SPL
        % tone
%     AudFreq         =   Par.Stm.Freq(k) * 1000; % kHz -> Hz
        % noise

    % multimodal
    MMType          = Par.Stm.MMType(k); % ms
    SomAudSOA       = Par.Stm.SomAudSOA(k); % ms

% somatosensory stimulus
if ismember(MMType,["OO","SO","SA"])
    [som_waveform,~] = gensomwaveform(Waveform,SomDur,Amplitude,SomFreq,SomRamp,Fs);
    SomDurSamp      =   length(som_waveform);
    RS.SetTagVal('SomDurSamp', SomDurSamp);
    RS.SetTagVal('SomEnable', 1);
    RS.WriteTagV('SomDataIn',0,som_waveform);
else
    RS.SetTagVal('SomEnable', 0);
end

% auditory stimulus
if ismember(MMType,["OA","SA"])
    switch AudStimType
        case {"NoiseBurst"}
            % -- generate stimulus --
            AudRiseFall    = Par.Stm.AudRiseFall(k); %ms
            AudFreqMin     = Par.Stm.AudFreqMin(k);
            AudFreqMax     = Par.Stm.AudFreqMax(k);
            LogDensity     = Par.Stm.LogDensity(k);
            Mf = 0; Md = 0; 
            MaskBand = 0; TransTime = -Inf;
            TransDur = 0;
            RiseTime = 0.001 * AudRiseFall; % ms -> s
            FallTime = 0.001 * AudRiseFall; % ms -> s
            Speaker = 1;
               
            Snd     =   genamnoise(AudDur/1000,AudIntensity,Mf,Md,AudFreqMin,AudFreqMax,LogDensity,...
                                    MaskBand,TransTime,TransDur,RiseTime,FallTime,...
                                    Fs,Speaker,Par.Gain,Par.Ref);
        otherwise
            Snd     = zeros(1,round(0.001*AudDur*Fs));
    end
    AudDurSamp = length(Snd);
    RS.SetTagVal('AudDurSamp', AudDurSamp);
    RS.SetTagVal('AudEnable', 1);
    RS.WriteTagV('AudDataIn',0,Snd);
else
    RS.SetTagVal('AudEnable', 0);
end

% set total duration (& for sound recording)
switch MMType
    case {"OO","SO"}
        TotalDur	    =	PreTime + SomDur + PostTime; %ms
    case {"OA"}
        TotalDur	    =	PreTime + AudDur + PostTime; %ms
    case {"SA"}
        if SomAudSOA >= 0
            StimDur = max(AudDur,SomDur+SomAudSOA);
        else
            StimDur = max(AudDur-SomAudSOA,SomDur);
        end
        TotalDur	    =	PreTime + StimDur + PostTime; %ms
end
TotalDurSamp    =   round(0.001 * TotalDur * Fs ); %ms -> samp

% set SOA
if strcmp(MMType,"SA")
    if SomAudSOA >= 0; SomDelSamp = round(0.001 * SomAudSOA * Fs ); AudDelSamp = 0; 
    else AudDelSamp = round(-0.001 * SomAudSOA * Fs ); SomDelSamp = 0; 
    end
else
    AudDelSamp = 0;
    SomDelSamp = 0;
end

Location	    =	Par.Stm.Location{k}; 

% -- transfer parameters to TDT ---
RS.SetTagVal('AudDelSamp', AudDelSamp);
RS.SetTagVal('SomDelSamp', SomDelSamp);
RS.SetTagVal('TotalDurSamp', TotalDurSamp);


%-- Update stimulus info text --%
hApp.StimulusTextArea.Text = [   {['Waveform: ', char(Waveform)]} ...
                                 {['StimDur: ' num2str(SomDur) ' ms']} ...
                                 {['Freq: ' num2str(SomFreq) ' Hz']} ...
								 {['Amplitude ' num2str(Amplitude) ' V']} ...
								 {['Location: ' char(Location)]} ...
								 {['Sound: ' char(AudStimType)]} ...
								 {['Intensity: ', num2str(AudIntensity), ' dB SPL']} ...
								 {['StimDur: ', num2str(AudDur), ' ms']} ...
								 {['SOA: ', num2str(SomAudSOA), ' ms']} ...
						     ];

Out		=	1;


function Out = setsomtrial(hApp,RS,Par,k,RecDur)

%-- Get parameters --%
Fs			    =	Par.Fs_stm;
% ISI			    =	Par.Stm.ISI(k); %ms
SomDur		    =	Par.Stm.SomDur(k); %ms
SomFreq         =   Par.Stm.SomFreq(k); % Hz
Amplitude	    =	Par.Stm.Amplitude(k); % V
Waveform        =   Par.Stm(k,:).Waveform;
Ramp            =   Par.Stm.Ramp(k); % ms

[som_waveform,~] = gensomwaveform(Waveform,SomDur,Amplitude,SomFreq,Ramp,Fs);

SomDurSamp     =   length(som_waveform);
TotalDur	    =	RecDur; %ms
TotalDurSamp    =   round(0.001 * TotalDur * Fs ); %ms -> samp
Location	    =	Par.Stm.Location{k}; 

% -- transfer parameters to TDT ---
RS.SetTagVal('AudEnable', 0);
RS.SetTagVal('SomDurSamp', SomDurSamp);
RS.WriteTagV('SomDataIn',0,som_waveform);
RS.SetTagVal('TotalDurSamp', TotalDurSamp);
% send mode to TDT?

% pause(0.05);

%-- Update stimulus info text --%
hApp.StimulusTextArea.Text = [   {['Waveform: ', Waveform]} ...
                                 {['StimDur: ' num2str(SomDur) ' ms']} ...
                                 {['Freq: ' num2str(SomFreq) ' Hz']} ...
								 {['Amplitude ' num2str(Amplitude) ' V']} ...
								 {['Location: ' Location]} ...
						     ];

Out		=	1;

function Amp = getamp(GainTable,Freq,Lvl,RefdB,DACmax)
% 
% %-- Select the closest frequency from the calibration table --%
% [~,idx]	=	min( abs(GainTable(:,1)-Freq) );
% Gain	=	GainTable(idx,2);
% 
% if( isnan(Lvl) || isinf(Lvl))
% 	Amp	=	0;
% else
% 	Amp		=	(10.^((Lvl-RefdB)/20)) ./ Gain;
% end
% 
% if( Amp >= DACmax )
% 	if( idx+1 > size(GainTable,1) )
% 		Gain	=	min([ mean( GainTable(idx-1:idx,2) ) 9]);
% 	else
% 		Gain	=	min([ mean( GainTable(idx-1:idx+1,2) ) 9]);
% 	end
% 	Amp		=	(10.^((Lvl-RefdB)/20)) ./ Gain;
% 	warning(['Used adjacent gains to calibrate f= ' num2str(round(Freq)) ' Hz & clipped to 9 V if necessary.'])
% end

    %-- Select interpolate gain from the calibration table --%
    uSpk = unique(GainTable(:,3));
    nSpk = length(uSpk);

    Gain2D = nan(nSpk,length(Freq));
    for s = 1:nSpk
        Spk = uSpk(s);
        GT = GainTable(GainTable(:,3) == Spk,:);
        Gain2D(s,:) = interp1(GT(:,1),GT(:,2),Freq(:));
    end

    Gain = mean(Gain2D,1); % if both speakers 

    Amp		=	(10.^((Lvl-RefdB)/20)) ./ Gain;

    if ( Amp >= DACmax )
        if( idx+1 > size(GainTable,1) )
            Gain	=	min([ mean( GainTable(idx-1:idx,2) ) 9]);
        else
            Gain	=	min([ mean( GainTable(idx-1:idx+1,2) ) 9]);
        end
        Amp		=	(10.^((Lvl-RefdB)/20)) ./ Gain;
        warning(['Used adjacent gains to calibrate f= ' num2str(round(Freq)) ' Hz & clipped to 9 V if necessary.'])
    end

function Out = setamtrial(hApp,RS,Par,k)%,RecDur)

Fs			=	Par.Fs_stm;

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	--%
S		=	Par.Stm(k,:);
RecType =   Par.Rec;

switch RecType
    case {'AM','AM1','AM2'}
        Snd			=	genripple(S.Mf,S.Dens,S.StimT,S.Intensity,S.Md,S.F0,S.Nfreq,Fs,S.Speaker,Par.Gain,Par.Ref);
    case {'AMn'}
        Snd     =   genamnoise(S.StimT/1000,S.Intensity,S.Mf,S.Md,S.FreqMin,S.FreqMax,S.LogDensity,...
                        S.MaskBand,S.TransTime,S.TransDur,S.RiseTime,S.FallTime,...
                        Fs,S.Speaker,Par.Gain,Par.Ref);
end

%-- Upload sound waveform & set associated tags --%
RS.WriteTagV('DataIn',0,Snd);
RS.SetTagVal('HiTime',S.StimT);
RS.SetTagVal('LoTime',0);
RS.SetTagVal('NPulse',1);

%-- Set recording duration --%
RecDur      =   S.PreT + S.StimT + S.PostT; %ms
ISI			=	S.ISI;  %ms
TotalDur	=	RecDur + ISI; %ms
TotalSamp	=	round(TotalDur * Fs / 1000);
RS.SetTagVal('TotalDur',TotalSamp);

%-- Set speakers & LED parameters --%
Spk		=	S.Speaker;

Sstr 	=	setspeaker(Spk,RS);

% -- Prepare text --
infotext = {};
switch RecType
    case {'AM','AM1','AM2'}
        
    case {'AMn'}
        infotext = [
                {['FreqRange: ' num2str(S.FreqMin/1000,'%.1f') '-' num2str(S.FreqMax/1000,'%.1f') ' kHz']}, ...
                {['Mask band: ' num2str(S.MaskBand) ' Hz']},...
                {['Transition: ' num2str(S.TransTime*1000) ' ms']},...
                ];
end
infotext = [ infotext, {['Int: ' num2str(S.Intensity) ' dB SPL']}, ...
                 {['Mf: ' num2str(S.Mf) ' Hz']}, ...
                 {['Md: ' num2str(S.Md) ]},...
                 {Sstr}	];

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14   15      16      17	 18	  19   20	 21		--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth SLvl Sloc F0 Nfreq  LVel LModDepth LInt Lloc Delay Color Type	--%
hApp.StimulusTextArea.Text = infotext;

Out	=	1;

function [Out,RandomState] = setomitrial(hApp,RS,Par,k)

Fs			=	Par.Fs_stm;

S		=	Par.Stm(k,:);
RecType =   Par.Rec;

% -- generate stimulus --
Mf = 0; Md = 0; LogDensity = 1;
MaskBand = 0; TransTime = -Inf;
TransDur = 0;
RiseTime = S.RiseFall;
FallTime = S.RiseFall;
ITI = S.ITI_s;

FreqRange = S.FreqRangeStd{:};
FreqMin = min(FreqRange);
FreqMax = max(FreqRange);

if (S.RandomSeed > 0); rng(S.RandomSeed); end % this seed for noise generation
RandomState = rng; 

Snd     =   genamnoise(S.StimT_ms/1000,S.LevelStd,Mf,Md,FreqMin,FreqMax,LogDensity,...
                        MaskBand,TransTime,TransDur,RiseTime,FallTime,...
                        Fs,S.SpeakerStd,Par.Gain,Par.Ref);

% -- calculate parameters for tdt
StimS = length(Snd);     
Conditions = S.Conditions{:}';
NStim = length(Conditions);
Period = round(S.SOA_ms / 1000 * Fs);
Cond = double(Conditions == 1);
%-- Upload sound waveform & set associated tags --%
RS.SetTagVal('HiTime',StimS);
RS.WriteTagV('DataIn',0,Snd);
RS.SetTagVal('NPulse',NStim);
RS.SetTagVal('Period',Period);
RS.WriteTagV('Cond',0,Cond);

%-- Set recording duration --%
TotalSamp	=	Period * NStim  +  ceil(ITI * Fs);
RS.SetTagVal('TotalDur',TotalSamp);

%-- Set speakers & LED parameters --%
Spk		=	S.SpeakerStd;

Sstr 	=	setspeaker(Spk,RS);

% pause(0.05);
% 	
% rgb		=	[0 0 0];

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14   15      16      17	 18	  19   20	 21		--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth SLvl Sloc F0 Nfreq  LVel LModDepth LInt Lloc Delay Color Type	--%
hApp.StimulusTextArea.Text = [ {['Int: ' num2str(S.LevelStd) ' dB SPL']}, ...
                                 {['Periodic: ' num2str(S.ConditionPer)]},...
                                 {['SOA: ' num2str(S.SOA_ms) ' ms']},...
								 {Sstr}	];

Out	=	1;

function [Snd,Fs] = genripple(Vel,Dens,Dur,Level,Mod,F0,Nfreq,Fs,Spk,Gain,Ref)
% [SND,FS] = GENCONTRIPPLE(VEL,DENS,MOD,DUR,FS,PLOTFLAG,PLAYFLAG)
%
% Generate a ripple stimulus with velocity (amplitude-modulation) VEL (Hz),
% density (frequency-modulation) DENS (cyc/oct), a modulation depth MOD
% (0-1), and a duration DUR (ms) at a sampling frequency of FS (Hz).
%
% These stimuli are parametrized naturalistic, speech-like sounds, whose
% envelope changes in time and frequency. Useful to determine
% spectro-temporal receptive fields (see e.g. Depireux et al., 2001 in J Neurophys).
%
% based on a function written by Marc van Wanrooij
% modified April 2017 by peterbr

% RefV		=	Ref(1,1);
RefdB		=	Ref(1,2);
DACmax		=	Ref(1,3);

if( Spk == 1 )		%-- Left Speaker only	--%
	sel			=	Gain(:,3) == 1;
	
elseif( Spk == 2 )	%-- Right Speaker only		--%
	sel			=	Gain(:,3) == 2;
end
Gain		=	Gain(sel,:);
%-- Main --%

%-- Carrier time axis --%
cSamp		=	round( (Dur/1000)*Fs );		%-- # samples		--%
cTime		=	( (1:cSamp)-1 ) / Fs;		%-- Time axis [sec]	--%

%-- According to Depireux et al. (2001) --%
FreqNr		=	0:1:Nfreq-1;
Freq		=	F0 * 2.^(FreqNr/20);
Oct			=	FreqNr/20;					%-- Octaves above F0		--%
Phi			=	pi - 2*pi*rand(1,Nfreq);	%-- Random starting	phase	--%
Phi(1)		=	pi/2;						%-- Set first to 0.5*pi		--%

%-- Generating amplitude modulation for the ripple --%
A			=	NaN(cSamp,Nfreq);
for k=1:cSamp
	for l=1:Nfreq
		A(k,l)	=	( 1 + Mod*sin(2*pi*Vel*cTime(k) + 2*pi*Dens*Oct(l)) );
	end
end

%-- Modulate carrier --%
ToneSPL		=	Level - 10 * log10(Nfreq);	%-- Each component contributes Lvl - 20*log10(# components) to the overall level --%

Snd			=	0;
for k=1:Nfreq
	
	Rip					=	A(:,k)'.* sin(2*pi* Freq(k) .* cTime + Phi(k));
	
	%-- Correct for speaker characteristics --%
	Amp		=	getamp(Gain,Freq(k),ToneSPL,RefdB,DACmax);

	Snd		=	Snd + Amp*Rip;
end

%-- Apply envelope --%
if( size(Snd,2) > 2 )
	Nenv			=	round( 5 *10^-3 * Fs );
	Snd				=	envelope(Snd',Nenv)';
end



function [zBus,RP] = setuptdt(RCOname)

f = figure(999);									%-- Must have a figure for the activeX controller		--%
set(f,'Visible','off');								%-- Hide the activeX figure --%
drawnow
pause(.3);											%-- We need this, else MATLAB dies if we restart FFRun!	--%

%-- Set up the ZBus --%
zBus	=	actxcontrol('ZBUS.x',[1 1 1 1]);
if ~zBus.ConnectZBUS('GB')
	herr	=	errordlg('Failed to init ZBus','Error in FFInit');
	set(herr,'position',ErrPosn);
	return
end

%-- Stimulation real-time processor --%
RS		=	actxcontrol('RPco.X');
% RS.ConnectRX6('GB',1);
RS.ConnectRZ6('GB',1);
RS.Halt;
RS.ClearCOF;
RS.LoadCOF(RCOname{1,1});

checktdtstatus(RS,RCOname{1,1});

%-- Recording real-time processor --%
% RR		=	actxcontrol('RPco.X');
% RR.ConnectRZ5('GB',1);
% RR.Halt;
% RR.ClearCOF;
% RR.LoadCOF(RCOname{2,1});
% 
% checktdtstatus(RR,RCOname{2,1});

%-- Store ActiveX objects in cell array --%
RP		=	{RS};

function checktdtstatus(RP,Str)

status	=	double(RP.GetStatus); % Gets the status
if bitget(status,1)==0 % Checks for connection
	disp('Error connecting to RP'); return;
elseif bitget(status,2)==0 % Checks for errors in loading circuit
	disp(['Error loading ' Str ' circuit!']); return;
% elseif bitget(status,3)==0 % Checks for errors in running circuit
% 	disp('Error running circuit'); return;
else
% 	disp('Circuit loaded and running');
	disp([Str ' circuit loaded']);
end


function Out = setfmtrial(hApp,RS,Par,k,RecDur)


Fs			=	Par.Fs_stm;

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11        12	 13     14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI  F0   F1     Slope   SlopeType Sloc SndLvl StmDur	--%
StmMtx		=	Par.StmMtx(k,:);				
[Snd,Dur]	=	genFMstim(StmMtx(1,8),StmMtx(1,9),StmMtx(1,11),StmMtx(1,10),StmMtx(1,13),Fs,Par.CalibrationPath,StmMtx(1,12),min(StmMtx(1,14)));

% Dsamp		=	ceil( (StmMtx(1,4)+StmMtx(1,5)+StmMtx(1,6))/1000*Par.Fs_stm );
Dsamp		=	1.95312e+006;
Dummy		=	zeros(1,Dsamp);

%-- Upload sound waveform & set associated tags --%
RS.WriteTagV('DataIn',0,Dummy);
RS.WriteTagV('DataIn',0,Snd);
RS.SetTagVal('HiTime',Dur*1000);
RS.SetTagVal('LoTime',0);
RS.SetTagVal('NPulse',1);

%-- Set recording duration --%
ISI			=	Par.StmMtx(k,7);
TotalDur	=	RecDur + ISI;
% TotalDur	=	StmMtx(:,4)+StmMtx(:,14);
TotalSamp	=	round(TotalDur * Fs / 1000);
RS.SetTagVal('TotalDur',TotalSamp);

%-- Set speakers & LED parameters --%
Spk		=	StmMtx(1,12);

Sstr 	=	setspeaker(Spk,RS);

pause(0.05);
	
% rgb		=	[0 0 0];
%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11        12	 13     14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI  F0   F1     Slope   SlopeType Sloc SndLvl StmDur	--%

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14   15      16      17	 18	  19   20	 21		--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth SLvl Sloc F0 Nfreq  LVel LModDepth LInt Lloc Delay Color Type	--%
hApp.StimulusTextArea.Text = [ {['Slvl ' num2str(StmMtx(1,13)) ' dBSPL']}, ...
								 {['Sloc ' num2str(StmMtx(1,12))]}, ...
								 {['Sslope ' num2str(StmMtx(1,10)) ' Oct/s']}, ...
								 {['Dur ' num2str((StmMtx(1,14)/1000))]}, ...
								 {Sstr}	];


Out	=	1;

function Sig = envelope(Sig, NEnv)
% Create a smooth on- and offset envelope for an auditory signal
%
% function SIG = ENVELOPE (SIG, NENV)
%
% .. Dr. P ...

if (length(NEnv) == 1); NEnv = [NEnv,NEnv];end

SigLen = size(Sig,1);

if (SigLen < 2*NEnv)

  disp ('-- ERROR: Envelope length greater than signal');

else

  Env1 = ( sin(0.5*pi*(0:NEnv(1))/NEnv(1)) ).^2;
  Env2 = flip( sin(0.5*pi*(0:NEnv(2))/NEnv(2)) ).^2;
  head = 1:(NEnv(1)+1);
  tail = (SigLen-NEnv(2)):SigLen;

  for i=1:size(Sig,2)
    Sig(head,i) = Env1' .* Sig(head,i);
    Sig(tail,i) = Env2' .* Sig(tail,i);
  end
end

function Aud = makefmtrl(Par)

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	--%

Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);
%Dur		=	str2double(Par.FMStimTime);
PreRec	=	str2double(Par.FMPreTime);
PostRec	=	str2double(Par.FMPostTime);
ISI		=	str2double(Par.FMISI);

%-- Auditory parameters --%
Sndloc	=	str2double(Par.FMLocation);
Sndlvl	=	str2double(Par.FMLevel);
FMSlope	=	eval(Par.FMSlope);
FMType	=	str2double(Par.FMSlopeType);
Frange	=	eval(Par.FMFRange)*1000;
F0		=	Frange(1);
F1		=	Frange(2);
Nrep	=	str2double(Par.FMRepetitions);

%-- Unimodal auditory stimulus parameters --%
[S,T,Cloc,L]	=	ndgrid(FMSlope',FMType',Sndloc',Sndlvl');

S		=	S(:);
T		=	T(:);
Cloc	=	Cloc(:);
L		=	L(:);
Aud		=	[S, T, Cloc, L];
NAud	=	size(Aud,1);
Dur		=	nan(NAud,1);

for k=1:NAud
	Koct		=	Aud(k,1);
	K			=	F0*10^-3 * 2^Koct;
	
	if Koct < 0
		tF0 =	F0;
		tF1 =	F1;
		dF0	=	tF1;
		dF1	=	tF0;
	elseif Koct > 0
		dF0 =	F0;
		dF1 =	F1;
	end
	
	Dur(k,1)=	log(dF1/dF0) / log(K);
% 	Dur(k,1)=	abs((dF0-dF1)/K);
end
Dur			=	Dur.*1000;
Aud			=	[Aud Dur];
Dur			=	max(Dur);
%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11       12	13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI  F0    F1    Slope  SlopeType Sloc SndLvl StmDur	--%
Aud		=	[	repmat(Aname,size(Aud,1),1) repmat(Nname,size(Aud,1),1) repmat(Pen,size(Aud,1),1) ...
				repmat(PreRec,size(Aud,1),1) repmat(Dur,size(Aud,1),1) repmat(PostRec,size(Aud,1),1) nan(size(Aud,1),1) ...
				 repmat(F0,size(Aud,1),1) repmat(F1,size(Aud,1),1) Aud ];
tAud	=	[Aname, Nname, Pen, PreRec, Dur, PostRec, NaN, F0, F1, 0, 1, 1, 60, max(Aud(:,14))];
% Aud		=	tAud;
Aud		=	[Aud; tAud];
%-- Trial randomization --%
Aud	=	randtrls(Aud,Nrep);

%-- Add random inter-stimulus interval --%
ISIrnd		=	getisi(ISI,size(Aud,1));
Aud(:,7)	=	ISIrnd;

function [Snd,Dur] = genFMstim(F0,F1,~,Slope,SndLvl,Fs,CalibrationPath,Spk,MxDur)
if Slope == 0
	MxDur	=	MxDur/1000;
	nSamp	=	round(MxDur*Fs);
	Snd		=	zeros(1,nSamp);
	Dur		=	MxDur;
	return
end

%-- Load tone gain table --%
T			=	load(CalibrationPath,'Gain','Ref');
Gain		=	T.Gain;
Ref			=	T.Ref;

% RefV		=	Ref(1,1);
RefdB		=	Ref(1,2);
DACmax		=	Ref(1,3);

if( Spk == 1 )		%-- Left Speaker only	--%
	sel			=	Gain(:,3) == 1;		
	
elseif( Spk == 2 )	%-- Right Speaker only		--%
	sel			=	Gain(:,3) == 2;		
end
Gain		=	Gain(sel,:);

K		=	F0*10^-3 * 2^Slope;	%-- Note that F0 needs to be in kHz: F0 * 10^-3 --%
if Slope < 0
	tF0 =	F0;
	tF1 =	F1;
	F0	=	tF1;
	F1	=	tF0;
end
Dur		=	log(F1/F0) / log(K);
X		=	0:1/Fs:Dur;

B		=	2 * pi * F0 / log(K);
Phase	=	B * K .^ X;

Nphase	=	length(Phase);
Octaves	=	linspace(0,log2(F1/F0),Nphase);
Freq	=	F0 .* 2.^(Octaves);
Amp		=	getamp(Gain,Freq,SndLvl,RefdB,DACmax);
Amp		=	movmean(Amp,round(Dur*Fs/2))';

% A		=	movmean(Amp,round(Dur*Fs/2));
% A2		=	movmean(Amp,round(Dur*Fs*0.25));
% myfig(1);
% plot(X,Amp,'k-')
% hold on
% plot(X,A,'r-')
% plot(X,A2,'b-')
% 
% Amp		=	mean(Amp);

Phase	=	Phase - min(Phase);
Y		=	Amp .* sin(Phase);
Snd		=	Y;

%-- Apply envelope --%
if( size(Snd,2) > 2 )
	Nenv			=	round( 5 *10^-3 * Fs );
	Snd				=	envelope(Snd',Nenv)';
% 	Y				=	Snd;
end


function Sstr = setspeaker(Spk,RS)
%correct as of 10/03/2020 (Maurits)
switch Spk
    case 3			%-- Binaural (not implemented)--%
	Sstr	=	'binaural';
	RS.SetTagVal('SndAOn',1);
	RS.SetTagVal('SndBOn',1);
	
    case 1		%-- Animal Right Speaker (SpkA) --%
	Sstr	=	'monaural right';
	RS.SetTagVal('SndAOn',1);
	RS.SetTagVal('SndBOn',0);
	
    case 2 		%-- Animal Left Speaker (SpkB) --%
	Sstr	=	'monaural left';
	RS.SetTagVal('SndAOn',0);
	RS.SetTagVal('SndBOn',1);
	
    case 0
	Sstr	=	'silent';
	RS.SetTagVal('SndAOn',0);
	RS.SetTagVal('SndBOn',0);
end
    
function Aud  =   makeAMtesttrl(Par)
        Aname	=	str2double(Par.MouseNum);
        Nname	=	str2double(Par.Set);
        Pen		=	str2double(Par.Penetration);
        
        Dur		=	str2double(Par.AMtStimTime);
        PreRec	=	str2double(Par.AMtPreTime);
        PostRec	=	str2double(Par.AMtPostTime);
        ISI		=	str2double(Par.AMtISI);
        
        Sndloc	=	str2double(Par.AMtLocation);
        Sndlvl	=	eval(Par.AMtLevel);
        Sndvel	=	eval(Par.AMtVelocity);
        Snddens	=	0;
        Sndmd	=	eval(Par.AMtModDepth);
        RipPar  =   eval(Par.AMtRipplePar);
        F0		=	RipPar(1,2);
        Nfreq	=	RipPar(1,1);
        Bandwid =   eval(Par.AMtBandwidth);
        BW      =   log2(Bandwid(1,2)/Bandwid(1,1));
        NBBand  =   eval(Par.AMtNBBandwidth);
        nNBStm  =   length(NBBand);
        
        Nrep	=	str2double(Par.AMtRepetitions);
        
        NStmT   =   2+nNBStm;
        
        %make ripple trials
        [V,D,M,S,L]	=	ndgrid(Sndvel',Snddens',Sndmd',Sndloc',Sndlvl');
        
        V		=	V(:);
        D		=	D(:);
        M		=	M(:);
        S		=	S(:);
        L		=	L(:);
        Aud		=	[V D M L S];
        
        sel		=	Aud(:,3) == 0;                      %Selecting all non-unmodulated stimuli
        Aud		=	Aud(~sel,:);                        %Unmodulated stimuli are removed from Aud
        
        for k=1:length(Sndlvl)
            Aud(end+1,:) = [NaN, 0, 0, Sndlvl(k), Sndloc];  %#ok<AGROW>
        end
        
        %--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	15      16 --%
        %--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	StmType BandWidth--%
        Aud1		=	[	repmat(Aname,size(Aud,1),1) repmat(Nname,size(Aud,1),1) repmat(Pen,size(Aud,1),1) ...
            repmat(PreRec,size(Aud,1),1) repmat(Dur,size(Aud,1),1) repmat(PostRec,size(Aud,1),1) nan(size(Aud,1),1) ...
            Aud repmat(F0,size(Aud,1),1) repmat(Nfreq,size(Aud,1),1) ones(size(Aud,1),1), nan(size(Aud,1),1) ];
        %-- Trial randomization --%
        %         Aud1	=	randtrls(Aud1,Nrep);
        
        %make broadband trials
        Aud2		=	[	repmat(Aname,size(Aud,1),1) repmat(Nname,size(Aud,1),1) repmat(Pen,size(Aud,1),1) ...
            repmat(PreRec,size(Aud,1),1) repmat(Dur,size(Aud,1),1) repmat(PostRec,size(Aud,1),1) nan(size(Aud,1),1) ...
            Aud repmat(Bandwid(1,1),size(Aud,1),1) nan(size(Aud,1),1) 2*ones(size(Aud,1),1), repmat(BW,(size(Aud,1)),1) ];
        %-- Trial randomization --%
        %         Aud2	=	randtrls(Aud2,Nrep);
        
        
        %make narrowband trials
        Aud3        =   [];
        for k=1:nNBStm
            OctStep         =   NBBand(1,k);
            nOctBlocks      =   BW/OctStep;
            NBF0            =   [];
            for m=1:nOctBlocks
                NBF0    =   [NBF0, (Bandwid(1,1)*2^(OctStep*(m-1)))];
            end
            
            [V,D,M,S,L,F]	=	ndgrid(Sndvel',Snddens',Sndmd',Sndloc',Sndlvl',NBF0);
            
            V		=	V(:);
            D		=	D(:);
            M		=	M(:);
            S		=	S(:);
            L		=	L(:);
            F       =   F(:);
            Aud		=	[V D M L S F];
            
            sel		=	Aud(:,3) == 0;                      %Selecting all non-unmodulated stimuli
            Aud		=	Aud(~sel,:);                        %Unmodulated stimuli are removed from Aud
            
            for n=1:length(NBF0)
                Aud(end+1,:) = [NaN, 0, 0, unique(Sndlvl), Sndloc, NBF0(1,n)];  %#ok<AGROW>
            end
            
            tAud		=	[	repmat(Aname,size(Aud,1),1) repmat(Nname,size(Aud,1),1) repmat(Pen,size(Aud,1),1) ...
                repmat(PreRec,size(Aud,1),1) repmat(Dur,size(Aud,1),1) repmat(PostRec,size(Aud,1),1) nan(size(Aud,1),1) ...
                Aud nan(size(Aud,1),1) 3*ones(size(Aud,1),1), repmat(OctStep,size(Aud,1),1) ];
            %-- Trial randomization --%
            %         tAud	=	randtrls(tAud,Nrep);
            
            Aud3        =   [Aud3; tAud];
        end
        
        Aud         =   [Aud1; Aud2; Aud3];
        
        Aud     =   randtrls(Aud,Nrep);
        
function Out = setamttrial(hApp,RS,Par,k,RecDur)
            
            
            Fs          =   Par.Fs_stm;
            StmMtx		=	Par.StmMtx(k,:);
            if StmMtx(1,10) == 0
                StmMtx(1,8) = 1;
            end
            
            if StmMtx(1,end-2) == 1
                Snd			=	genripple(StmMtx(1,8),StmMtx(1,9),StmMtx(:,5),StmMtx(1,11),StmMtx(1,10),StmMtx(1,13),StmMtx(1,14),Fs,StmMtx(1,12),Par.CalibrationPath);
            else
                Snd         =   gennoise(StmMtx(1,8),StmMtx(:,5),StmMtx(1,11),StmMtx(1,10),StmMtx(1,13),StmMtx(1,16),Par.Fs_stm,StmMtx(1,12),Par.CalibrationPath);
                
            end
            
            %-- Apply envelope --%
            if( size(Snd,2) > 2 )
                Nenv			=	round( 5 *10^-3 * Par.Fs_stm );
                Snd				=	envelope(Snd',Nenv)';
            end
            
            %-- Upload sound waveform & set associated tags --%
            RS.WriteTagV('DataIn',0,Snd);
            RS.SetTagVal('HiTime',StmMtx(:,5));
            RS.SetTagVal('LoTime',0);
            RS.SetTagVal('NPulse',1);
            
            %-- Set recording duration --%
            ISI			=	0;
            TotalDur	=	RecDur + ISI;
            TotalSamp	=	round(TotalDur * Fs / 1000);
            RS.SetTagVal('TotalDur',TotalSamp);
            
            %-- Set speakers & LED parameters --%
            Spk		=	StmMtx(1,12);
            
            Sstr 	=	setspeaker(Spk,RS);
            if StmMtx(1,end-2) == 1
                hApp.StimulusTextArea.Text = [ {'Noise = Ripple' }, ...
                    {['Slvl ' num2str(StmMtx(1,11)) ' dBSPL']}, ...
                    {Sstr}, ...
                    {['Svel ' num2str(StmMtx(1,8)) ' Hz']}, ...
                    {['Smd ' num2str(StmMtx(1,10))]}, ...
                    ];
            elseif StmMtx(1,end-2) == 2
                hApp.StimulusTextArea.Text = [ {['Noise = Broadband'  ]}, ...
                    {['Bandwidth = ' Par.AMtBandwidth]}, ...
                    {['Slvl ' num2str(StmMtx(1,11)) ' dBSPL']}, ...
                    {Sstr}, ...
                    {['Svel ' num2str(StmMtx(1,8)) ' Hz']}, ...
                    {['Smd ' num2str(StmMtx(1,10))]}, ...
                    ];
            elseif StmMtx(1,end-2) == 3
                hApp.StimulusTextArea.Text = [ {'Noise = Narrowband' }, ...
                    {['F0 = ' num2str(StmMtx(1,13)) 'kHz']}, ...
                    {['NB Bandwidth = ' num2str(StmMtx(1,16)) ' oct']},...
                    {['Slvl ' num2str(StmMtx(1,11)) ' dBSPL']}, ...
                    {Sstr}, ...
                    {['Svel ' num2str(StmMtx(1,8)) ' Hz']}, ...
                    {['Smd ' num2str(StmMtx(1,10))]}, ...
                    ];
            end
            Out	=	1;

function    [mainSnd,sideSnd,TT]    =   gencinoise(Fs,logdensity,FreqBand,Int,Dur,Gain,Ref,...
    guardBand,NoiseRamp,NotchBand)
% function to generate different kind of noise

%% Basic parameters
FSam        =   Fs;             % Hz; Sampling Rate
useLogDensity = logdensity;
SidePower    =  1; % power

if nargin < 8|| isempty(guardBand)||length(FreqBand) == 1 ; guardBand = 0;end % Hz
if nargin < 9|| isempty(NoiseRamp)||length(FreqBand) == 1 ; NoiseRamp = 0;end % Hz
if nargin < 10|| isempty(NotchBand); Notch = 0; else; Notch = 1 ; end

%% Specify Frequency Bands
if length(FreqBand) == 1 
    f1      =   (FreqBand(1,1)*1000);      %kHz -> Hz lower bound
    f2      =   (FreqBand(1,1)*1000);      %kHz -> Hz upper bound
else
    f1      =   (FreqBand(1,1)*1000);      %kHz -> Hz lower bound
    f2      =   (FreqBand(1,2)*1000);      %kHz -> Hz upper bound
end

MaskFreqs   = [f1 - guardBand,...
             f1 + NoiseRamp + guardBand,...
             f2 - NoiseRamp - guardBand,...
             f2 + guardBand];

if (max(MaskFreqs) > FSam / 2)
   warning('Nyquist is violated!!!') 
end

%% Derived parameters
nSamp       =   round(FSam*Dur);           % Number of samples in signal
dF          =   1/Dur;              % frequency resolution

if (Int == -Inf || f1 == 0)
    mainSnd         =   zeros(1,nSamp);
    sideSnd         =   zeros(1,nSamp);
    TT              =   [0:nSamp-1]./FSam;    % time axis vector
    return
end

%% Use Calibration
DACmax      =   Ref(1,3);
RefdB       =   Ref(1,2);

% Generate Signal
%% Select frequncy band
FF          =   0:dF:dF*(nSamp-1);  % Freq Axis

mainIdx     =   (FF >= f1) & (FF <= f2);
sideIdx     =   (FF >= MaskFreqs(1)) & (FF < MaskFreqs(2))...
                    | (FF > MaskFreqs(3)) & (FF <= MaskFreqs(4));

mainN       =   sum([mainIdx]);           % number of freq samples in band
sideN       =   sum([sideIdx]);       % number of freq samples in band

if Notch == 1
    notchIdx    =   (FF >= NotchBand(1)) & (FF <= NotchBand(2));
    notchN      =   sum([notchIdx]);            % number of freq samples in band
end

%% Generate random phased spectrum

mainXX          =   zeros(1,nSamp);   % initialize with zeros
mainXX(mainIdx) =   exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

if NoiseRamp > 0
    rampIdx1 = (FF >= f1) & (FF < f1 + NoiseRamp);
    rampIdx2 = (FF > f2 - NoiseRamp) & (FF <= f2);
    mainXX(rampIdx1) = mainXX(rampIdx1) .* sqrt(linspace(0,1,sum(rampIdx1)));
    mainXX(rampIdx2) = mainXX(rampIdx2) .* sqrt(linspace(1,0,sum(rampIdx2)));
end

sideXX          =   zeros(1,nSamp);   % initialize with zeros
sideXX(sideIdx) =   sqrt(SidePower) * exp(2*pi*rand(1,sideN)*1i); % euler form - flat spectrum

mainN       =   sum(abs(mainXX).^2);  % number of freq samples in band
sideN       =   sum(abs(sideXX).^2);  % number of freq samples in band
totalN      =   mainN + sideN;  % number of freq samples in band

%% log vs linear power density scaling
if useLogDensity > 0
    rawMS = rms(sideXX+mainXX)^2;

    logDenIdx   = FF >  useLogDensity; % anything above useLogDensity will be 1/f
    flatIdx     = FF <= useLogDensity; % anything <= useLogDensity will be flat
    
    % apply 1/f scaling
    sideXX_logden(logDenIdx)  =   sideXX(logDenIdx) ./ sqrt(FF(logDenIdx));
    mainXX_logden(logDenIdx)  =   mainXX(logDenIdx) ./ sqrt(FF(logDenIdx));
    
    % apply flat scaling
    sideXX_logden(flatIdx)  =   sideXX(flatIdx) ./ sqrt(useLogDensity);
    mainXX_logden(flatIdx)  =   mainXX(flatIdx) ./ sqrt(useLogDensity);

    % rescale total power (RMS)
    newMS       =   rms(sideXX_logden+mainXX_logden)^2;
    scale       =   sqrt(rawMS / newMS);
    sideXX      =   sideXX_logden .* scale;
    mainXX      =   mainXX_logden .* scale;
end

%% insert notch
if Notch == 1
    mainXX(notchIdx) = 0;   
end

%% apply calibration
% ToneSPL		=	Int - 10 * log10(totalN);	%-- Each component contributes Lvl - 10*log10(# components) to the overall level --%
% -- scale so that main sound is the target intensity --
ToneSPL		=	Int - 10 * log10(mainN);	%-- Each component contributes Lvl - 10*log10(# components) to the overall level --%

sideXX(sideIdx)      =   sideXX(sideIdx).*getamp(Gain,FF(sideIdx),ToneSPL,RefdB,DACmax);
mainXX(mainIdx)      =   mainXX(mainIdx).*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

%% generate t-domain signal

mainSnd         =   fft(mainXX);  % fft;
sideSnd         =   fft(sideXX);  % fft;
TT              =   [0:nSamp-1]./FSam;    % time axis vector
            
function Snd         =   gennoise(Vel,Dur,Level,Mod,F0,Bandwidth,Fs,Spk,CalPath)
    
% Derived parameters
Dur         =   Dur/1000;
nSamp       =   round(Fs*Dur);           % Number of samples in signal
dF          =   1/Dur;                      % frequency resolution
fLow        =   1000*F0;
fHigh       =   fLow*2^(Bandwidth);

load(CalPath,'Gain','Ref');
DACmax      =   Ref(1,3);
RefdB       =   Ref(1,2);

% Generate Signal
% Select frequncy band
FF          =   0:dF:dF*(nSamp-1);  % Freq Axis
idx         =   (FF >= fLow) & (FF <= fHigh);
nn          =   sum(idx);           % number of freq samples in band
%amp         =   sqrt(2) * totAmp / sqrt(nn); % scale amplitude sqrt(2) for pk-pk -> rms; sqrt(nn) for number of samples
% Generate random phased spectrum
XX          =   zeros(1,nSamp);   % initialize with zeros
XX(idx)     =   exp(2*pi*rand(1,nn)*1i); % euler form - flat spectrum

ToneSPL		=	Level - 10 * log10(nn);	%-- Each component contributes Lvl - 20*log10(# components) to the overall level --%

indices = find(idx);
for k=1:length(indices)
    XX(indices(k))         = XX(indices(k))*getamp(Gain,FF(indices(k)),ToneSPL,RefdB,DACmax);
end
%%% HERE YOU WOULD DIVIDE AMP WITH THE FREQ DEPENDENT CALIBRATION %%%%

    
Snd         =   real(fft(XX));  % fft
t           =   0:1/Fs:Dur;
if Vel ~= 1
    AMenv       =   1 + (Mod * sin((Vel * t)*(2*pi)));
    Snd         =   Snd .* AMenv;
end


function FRA = makefrastm(Par)
    
Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);
Nrep	=	str2double(Par.FRARepetitions);
Dur		=	str2double(Par.FRAStimTime);
PreRec	=	str2double(Par.FRAPreTime);
PostRec	=	str2double(Par.FRAPostTime);
ISI		=	str2double(Par.FRAISI);
Spk		=	str2double(Par.FRALocation);
Level	=	eval(Par.FRALevel);
Freq	=	eval(Par.FRAFreqRange);
Oct		=	eval(Par.FRAOctStep);

if( Oct ~= 0 && length(Freq) > 1 )
	Freq	=	Freq(1) * 2.^(0:Oct:log2(Freq(2)/Freq(1)));
end

%random parameters
[Freq,Intensity,Speaker]	=	meshgrid(Freq,Level,Spk);
% add silent trial
Freq  =   [Freq(:);0]; 
Intensity  =   [Intensity(:);-Inf]; 
Speaker  =   [Speaker(:);0]; 
Nfl		=	size(Freq,1);

FRA = table(Freq,Intensity,Speaker);

%-- Trial randomization --%
FRA		=	randtrls(FRA,Nrep);

%--					1					2					3					4					5					 6				 7		 8		 9	 10	--%
%--				Animal name			Set number			Penetration			Pre-Record			Duration			Post-Record			ISI		Freq	Lvl	Spk	--%
% FRA		=	[repmat(Aname,Nfl,1) repmat(Nname,Nfl,1)   repmat(Pen,Nfl,1)   repmat(PreRec,Nfl,1) repmat(Dur,Nfl,1)  repmat(PostRec,Nfl,1) nan(Nfl,1)    FLS];

NStm            = size(FRA,1);

% insert static parameters
FRA.MouseNum	=	repmat(Aname,NStm,1);
FRA.Set         =	repmat(Nname,NStm,1);
FRA.Pen         =	repmat(Pen,NStm,1);
FRA.PreT		=	repmat(PreRec,NStm,1);
FRA.StimT		=	repmat(Dur,NStm,1);
FRA.PostT		=	repmat(PostRec,NStm,1);

% insert randomized parameters
FRA.ISI         =	getisi(ISI,NStm);


function Opt = makeoptostm(Par)
    
Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);
Nrep	=	str2double(Par.OptoRepetitions);
ToneDur		=	str2double(Par.FRAStimTime);
PreRec	=	str2double(Par.FRAPreTime);
PostRec	=	str2double(Par.FRAPostTime);
ISI		=	str2double(Par.OptoISI);
LEDDurs	=	str2num(Par.LEDDurs); %#ok<ST2NM>
LEDDelays	=	str2num(Par.LEDDelays); %#ok<ST2NM>

if (min(LEDDelays)+PreRec <= 0)
    PreRec = -min(LEDDelays)+1;
end

switch Par.Rec
    case 'OptoFRA'
        Spk		=	str2double(Par.FRALocation);
        Level	=	eval(Par.FRALevel);
        Freq	=	eval(Par.FRAFreqRange);
        Oct		=	eval(Par.FRAOctStep);

        if( Oct ~= 0 && length(Freq) > 1 )
            Freq	=	Freq(1) * 2.^(0:Oct:log2(Freq(2)/Freq(1)));
        end
        
        [Freq,Intensity,Speaker]	=	meshgrid(Freq,Level,Spk);
        
    case 'Opt'
        Freq	=	[];
        Intensity = [];
        Speaker = [];
    otherwise
        Freq	=	[];
        Intensity = [];
        Speaker = [];
end

% add silent trial
Freq  =   [Freq(:);0]; 
Intensity  =   [Intensity(:);-Inf]; 
Speaker  =   [Speaker(:);0]; 
Nfl		=	size(Freq,1);

[~,~,Freq]                  =	ndgrid(LEDDurs,LEDDelays,Freq);
[~,~,Intensity]             =	ndgrid(LEDDurs,LEDDelays,Intensity);
[LEDDur,LEDDelay,Speaker]	=	ndgrid(LEDDurs,LEDDelays,Speaker);
LEDDur=LEDDur(:);LEDDelay=LEDDelay(:);Freq = Freq(:); Intensity = Intensity(:); Speaker = Speaker(:);
Opt = table(LEDDur,LEDDelay,Freq,Intensity,Speaker);

%-- Trial randomization --%
Opt		=	randtrls(Opt,Nrep);

%--					1					2					3					4					5					 6				 7		 8		 9	 10	--%
%--				Animal name			Set number			Penetration			Pre-Record			Duration			Post-Record			ISI		Freq	Lvl	Spk	--%
% FRA		=	[repmat(Aname,Nfl,1) repmat(Nname,Nfl,1)   repmat(Pen,Nfl,1)   repmat(PreRec,Nfl,1) repmat(Dur,Nfl,1)  repmat(PostRec,Nfl,1) nan(Nfl,1)    FLS];

NStm            = size(Opt,1);

% insert static parameters
Opt.MouseNum	=	repmat(Aname,NStm,1);
Opt.Set         =	repmat(Nname,NStm,1);
Opt.Pen         =	repmat(Pen,NStm,1);
Opt.PreT		=	repmat(PreRec,NStm,1);
Opt.ToneT		=	repmat(ToneDur,NStm,1);
Opt.PostT		=	repmat(PostRec,NStm,1);

% insert randomized parameters
Opt.ISI         =	getisi(ISI,NStm);

function Som = makesomstm(Par)
% block design first, FRA then SOM

Aname	    =	str2double(Par.MouseNum);
Nname	    =	str2double(Par.Set);
Pen		    =	str2double(Par.Penetration);
SomDurs	    =	str2double(Par.SomatosensoryStimTime);
Nrep	    =	str2double(Par.SomatosensoryRepetitions);
ISI		    =	str2double(Par.SomatosensoryISI);
Amplitudes	=	str2num(Par.SomatosensoryAmplitude,Evaluation='restricted'); %#ok<ST2NM>
Location	=	Par.SomatosensoryLocation; 
Actuator	=	Par.SomatosensoryActuator; 
Waveform	=	Par.SomatosensoryWaveform; 
Offset	    =	str2double(Par.SomatosensoryOffset); 
Ramp	    =	str2double(Par.SomatosensoryRamp); 

switch Waveform
    case {'Square'}
        SomFreqs = 0;
    case {'UniSine','BiSine'}
        SomFreqs = str2num(Par.SomatosensoryFrequency,Evaluation='restricted'); %#ok<ST2NM> 
end

ToneDur	=	str2double(Par.FRAStimTime);
PreRec	    =	str2double(Par.FRAPreTime);
PostRec	=	str2double(Par.FRAPostTime);

switch Par.Rec
    case 'SOM'
        AudFreq	=	[];
        AudIntensity = [];
        Speaker = [];
    case 'SOM_FRA'
        Spk		=	str2double(Par.FRALocation);
        Level	=	eval(Par.FRALevel);
        AudFreq	=	eval(Par.FRAFreqRange);
        Oct		=	eval(Par.FRAOctStep);

        if( Oct ~= 0 && length(AudFreq) > 1 )
            AudFreq	=	AudFreq(1) * 2.^(0:Oct:log2(AudFreq(2)/AudFreq(1)));
        end

        % Create all combinations of Freq, Level and Spk
        [AudFreq, AudIntensity, Speaker]	=	meshgrid(AudFreq, Level, Spk);

    otherwise
        AudFreq	=	[];
        AudIntensity = [];
        Speaker = [];
end
%----------------------- ADAPTED FROM OPT
% would work for som alone + SOM + FRA simultaneous
% add silent trial
AudFreq  =   [AudFreq(:);0]; 
AudIntensity  =   [AudIntensity(:);-Inf]; 
Speaker  =   [Speaker(:);0]; 

% make table of all stimulus combinations
[~,~,~,AudFreq]                  =	ndgrid(SomDurs,Amplitudes,SomFreqs,AudFreq);
[~,~,~,AudIntensity]             =	ndgrid(SomDurs,Amplitudes,SomFreqs,AudIntensity);
[SomDur,Amplitude,SomFreq,Speaker]	=	ndgrid(SomDurs,Amplitudes,SomFreqs,Speaker);


SomDur = SomDur(:);
Amplitude = Amplitude(:);
SomFreq = SomFreq(:);
    SomFreq(Amplitude == 0) = 0;  % set Amplitude = 0 => Freq = 0
    % TODO: control the number of zero amplitude trials
AudFreq = AudFreq(:);
AudIntensity = AudIntensity(:);
Speaker = Speaker(:);
Som = table(SomDur,Amplitude,SomFreq,AudFreq,AudIntensity,Speaker);

%-- Trial randomization for Nrep repetitions--%
Som		=	randtrls(Som, Nrep);
%---------------------

NStm            = size(Som,1);

% insert static parameters
Som.Actuator    =	repmat(Actuator,NStm,1);
Som.Waveform    =	repmat(Waveform,NStm,1);
Som.Offset      =	repmat(Offset,NStm,1);
Som.Ramp        =	repmat(Ramp,NStm,1);
Som.Location    =	repmat({Location},NStm,1);
Som.ISI         =	repmat(ISI,NStm,1);
Som.MouseNum	=	repmat(Aname,NStm,1);
Som.Set         =	repmat(Nname,NStm,1);
Som.Pen         =	repmat(Pen,NStm,1);

function SxA = makeSomAudStm(Par)

% --- Expt/Session parameter ---
Aname	    =	str2double(Par.MouseNum);
Nname	    =	str2double(Par.Set);
Pen		    =	str2double(Par.Penetration);

% --- Set parameters ---
    % general timing
    Nrep	    =	str2double(Par.SomatosensoryRepetitions);
    ISI		    =	str2double(Par.SomatosensoryISI);

    % somatosensory
    SomDurs	    =	str2double(Par.SomatosensoryStimTime);
    Amplitudes	=	str2num(Par.SomatosensoryAmplitude,Evaluation='restricted'); %#ok<ST2NM>
    Location	=	string(Par.SomatosensoryLocation); 
    Actuator	=	string(Par.SomatosensoryActuator); 
    Waveform	=	string(Par.SomatosensoryWaveform); 
    Offset	    =	str2double(Par.SomatosensoryOffset); 
    SomRamp	    =	str2double(Par.SomatosensoryRamp); 
    switch Waveform
        case {'Square'}
            SomFreqs = 0;
        case {'UniSine','BiSine'}
            SomFreqs = str2num(Par.SomatosensoryFrequency,Evaluation='restricted'); %#ok<ST2NM> 
    end

    % auditory
    AudStimType     = string(Par.AuditoryStimulusType);
    AudDurs          = str2double(Par.AuditoryStimTime); % ONLY one duration allowed ATM
    % AudFreqs % NOT USED
    AudIntensities  = str2num(Par.AuditoryIntensity,Evaluation='restricted'); %#ok<ST2NM>
    AudRiseFall     = 5; %ms
    AudFreqMin     = 2e3;
    AudFreqMax     = 64e3;
    LogDensity     = 1;

    % S-A multimodal
    SomAudSOA       = str2num(Par.SomAudSOA,Evaluation='restricted'); %#ok<ST2NM>
   

% make table of all SOM stimulus combinations
[SomDur,Amplitude,SomFreq]	=	ndgrid(SomDurs,Amplitudes,SomFreqs);
SomDur = SomDur(:); Amplitude = Amplitude(:); SomFreq = SomFreq(:); % linearize
    SomFreq(Amplitude == 0) = 0;  % set Amplitude = 0 => Freq = 0
    if ismember(Waveform,{'UniSine','BiSine'}) % for sinusoidal stim: set Freq = 0 => Amplitude = 0 
        Amplitude(SomFreq == 0) = 0;
    end
Som = table(SomDur,Amplitude,SomFreq);
NStm            = size(Som,1);

Som.Actuator    =	repmat(Actuator,NStm,1);
Som.Waveform    =	repmat(Waveform,NStm,1);
Som.Offset      =	repmat(Offset,NStm,1);
Som.SomRamp     =	repmat(SomRamp,NStm,1);
Som.Location    =	repmat(Location,NStm,1);

idx = Som.Amplitude > 0;
SomActive = Som(idx,:);
SomNull = unique(Som(~idx,:)); % to have a single control stimulus

% make table of all Aud stimuli
switch AudStimType
    case {'NoiseBurst'}
        [AudDur,AudIntensity]	=	ndgrid(AudDurs,AudIntensities);
        AudDur = AudDur(:); AudIntensity = AudIntensity(:); % linearize
        AudActive = table(AudDur,AudIntensity);
            NStm            = size(AudActive,1);
            AudActive.AudStimType = repmat(AudStimType,NStm,1);
            AudActive.AudRiseFall = repmat(AudRiseFall,NStm,1);
            AudActive.AudFreqMin  = repmat(AudFreqMin,NStm,1);
            AudActive.AudFreqMax  = repmat(AudFreqMax,NStm,1);
            AudActive.LogDensity  = repmat(LogDensity,NStm,1); %#ok<REPMAT> 
        AudNull = table(0,-Inf,'VariableNames',{'AudDur','AudIntensity'});
            AudNull.AudStimType = AudStimType;
            AudNull.AudRiseFall = AudRiseFall;
            AudNull.AudFreqMin  = AudFreqMin;
            AudNull.AudFreqMax  = AudFreqMax;
            AudNull.LogDensity  = LogDensity;
end

% make table of multimodal parameters
SOA = table(SomAudSOA);
SOANull = table(NaN,'VariableNames',{'SomAudSOA'});

% combine parameters
OO = meshtable(SomNull,     AudNull,  SOANull,table("OO",'VariableNames',{'MMType'}));
SO = meshtable(SomActive,   AudNull,  SOANull,table("SO",'VariableNames',{'MMType'}));
OA = meshtable(SomNull,     AudActive,SOANull,table("OA",'VariableNames',{'MMType'}));
SA = meshtable(SomActive,   AudActive,SOA,    table("SA",'VariableNames',{'MMType'}));
SxA = [OO;SO;OA;SA];

%-- Trial randomization for Nrep repetitions--%
SxA		=	randtrls(SxA, Nrep);
%---------------------

NStm            = size(SxA,1);

% insert static parameters
SxA.ISI         =	repmat(ISI,NStm,1);
SxA.MouseNum	=	repmat(Aname,NStm,1);
SxA.Set         =	repmat(Nname,NStm,1);
SxA.Pen         =	repmat(Pen,NStm,1);


function Stm = makeAMstm(Par)

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	--%

Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);

switch Par.Rec
    case {'AM1','AM2'}
        Dur		=	str2double(Par.AMStimTime);
        PreRec	=	str2double(Par.AMPreTime);
        PostRec	=	str2double(Par.AMPostTime);
        ISI		=	str2double(Par.AMISI);

        %-- Auditory parameters --%
        Sndloc	=	str2double(Par.AMLocation);
        Sndlvl	=	eval(Par.AMLevel);
        Sndvel	=	eval(Par.AMVelocity);
        Snddens	=	0;
        Sndmd	=	eval(Par.AMModDepth);
        F0		=	str2double(Par.AMF0);
        Nfreq	=	str2double(Par.AMNFreq);

        Nrep	=	str2double(Par.AMRepetitions);
	
    case {'STRF'}
        Dur		=	str2double(Par.STRFStimTime);
        PreRec	=	str2double(Par.STRFPreTime);
        PostRec	=	str2double(Par.STRFPostTime);
        ISI		=	str2double(Par.STRFISI);

        %-- Auditory parameters --%
        Sndloc	=	str2double(Par.STRFLocation);
        Sndlvl	=	str2double(Par.STRFLevel);
        Sndvel	=	eval(Par.STRFVelocity);
        Snddens	=	eval(Par.STRFDensity);
        Sndmd	=	eval(Par.STRFModDepth);
        F0		=	str2double(Par.STRFF0);
        Nfreq	=	str2double(Par.STRFNFreq);

        Nrep	=	str2double(Par.AMRepetitions);
end

%-- Unimodal auditory stimulus parameters --%
if (any(Sndmd == 0));    addZero = 1; else addZero = 0; end
Sndmd = Sndmd(Sndmd ~= 0);
[Mf,Dens,Md,Speaker,Intensity]	=	ndgrid(Sndvel',Snddens',Sndmd',Sndloc',Sndlvl');

Mf		=	Mf(:);
Dens    =   Dens(:);
Md		=	Md(:);
Speaker		=	Speaker(:);
Intensity		=	Intensity(:);
if (addZero) %issue here with AM2 where multiple sound levels are added, but only one value for Mf, Speaker, Md and Dens
    NLvl        = length(Sndlvl);
    Intensity   = [Intensity; Sndlvl(:)];
    Speaker     = [Speaker;repmat(Sndloc,NLvl,1)];
    Mf          = [Mf;zeros(NLvl,1)];
    Md          = [Md;zeros(NLvl,1)];
    Dens        = [Dens;zeros(NLvl,1)];
end

Stm		=	table(Mf, Dens, Md, Intensity, Speaker);

%-- Trial randomization --%
Stm	=	randtrls(Stm,Nrep);
% Aud(end+1,:) = [NaN, 0, 0, Sndlvl, Sndloc];     %Single unmodulated stimulus is added to Aud

NStm            = size(Stm,1);

% insert static parameters
Stm.MouseNum	=	repmat(Aname,NStm,1);
Stm.Set         =	repmat(Nname,NStm,1);
Stm.Pen         =	repmat(Pen,NStm,1);
Stm.PreT		=	repmat(PreRec,NStm,1);
Stm.StimT		=	repmat(Dur,NStm,1);
Stm.PostT		=	repmat(PostRec,NStm,1);
Stm.F0          =   repmat(F0,NStm,1);
Stm.Nfreq       =   repmat(Nfreq,NStm,1);
% insert randomized parameters
Stm.ISI         =	getisi(ISI,NStm);

function Stm = makeAMnoisestm(Par)

%--	  1		 2	   3	 4	   5	  6		7	8	  9	     10	     11  12	  13   14	--%
%--	Animal	Set   Pen Pre-Rec Dur Post-Rec ISI SVel SDens SModDepth Slvl Sloc F0 Nfreq	--%

Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);

RiseTime = 5e-3; %s
FallTime = 5e-3; %s

switch Par.Rec
    case {'AMn'}
        Dur		=	str2double(Par.AMStimTime); %ms
        PreRec	=	str2double(Par.AMPreTime); %ms
        PostRec	=	str2double(Par.AMPostTime); %ms
        ISI		=	str2double(Par.AMISI); %ms

        %-- Auditory parameters --%
        Sndloc	=	str2double(Par.AMLocation);
        Sndlvl	=	eval(Par.AMLevel); % dB
        Sndvel	=	eval(Par.AMVelocity); % Hz
        Sndmd	=	eval(Par.AMModDepth); % [0,1]
        FreqMin =	str2double(Par.AMF0); % Hz
        FreqMax	=	str2double(Par.AMFreqMax); % Hz
        Sndtrans = eval(Par.AMTransTime)/1000; %ms -> s
        transDur = eval(Par.AMTransDur)/1000; %ms -> s
        logDensity = Par.AMLogDensity; % 0 or 1;
        if (isempty(Par.AMMaskBand))
            SndMask = max(Sndvel);
        else
            SndMask =eval(Par.AMMaskBand);    % Hz
            SndMask(isinf(SndMask)|isnan(SndMask)) = max(Sndvel);
        end
        SndMask = unique(SndMask);

        Nrep	=	str2double(Par.AMRepetitions);
end

%-- Unimodal auditory stimulus parameters --%
if (any(Sndmd == 0));    addZero = 1; else; addZero = 0; end
Sndmd = Sndmd(Sndmd ~= 0);Sndvel = Sndvel(Sndvel ~= 0);

[Mf,Md,Speaker,Intensity,TransTime,MaskBand]	=	ndgrid(Sndvel',Sndmd',Sndloc',Sndlvl',Sndtrans',SndMask');

Mf          =	Mf(:);
Md          =	Md(:);
Speaker		=	Speaker(:);
Intensity	=	Intensity(:);
TransTime   =   TransTime(:);
MaskBand   =   MaskBand(:);

if (addZero) % zero modulation
    [ZeroSpeaker,ZeroIntensity,ZeroTransTime]	=	ndgrid(Sndloc',Sndlvl',Sndtrans');
    ZeroSpeaker = ZeroSpeaker(:);
    ZeroIntensity = ZeroIntensity(:);
    ZeroTransTime = ZeroTransTime(:);

    NZero        = length(ZeroIntensity); 
    Intensity   = [Intensity; ZeroIntensity(:)]; % different intensities
    Speaker     = [Speaker;ZeroSpeaker]; % assume single speaker
    Mf          = [Mf;zeros(NZero,1)]; % Mf = 0
    Md          = [Md;zeros(NZero,1)]; % Md = 0
    TransTime  = [TransTime;ZeroTransTime]; %
    MaskBand  = [MaskBand;zeros(NZero,1)]; % masking does not matter.
end

Stm		=	table(Mf, Md, Intensity, Speaker,TransTime,MaskBand);

%-- Trial randomization --%
Stm	=	randtrls(Stm,Nrep);
% Aud(end+1,:) = [NaN, 0, 0, Sndlvl, Sndloc];     %Single unmodulated stimulus is added to Aud

NStm            = size(Stm,1);

% insert static parameters
Stm.MouseNum	=	repmat(Aname,NStm,1);
Stm.Set         =	repmat(Nname,NStm,1);
Stm.Pen         =	repmat(Pen,NStm,1);
Stm.PreT		=	repmat(PreRec,NStm,1);
Stm.StimT		=	repmat(Dur,NStm,1);
Stm.PostT		=	repmat(PostRec,NStm,1);
Stm.FreqMin     =   repmat(FreqMin,NStm,1);
Stm.FreqMax     =   repmat(FreqMax,NStm,1);
Stm.TransDur    =   repmat(transDur,NStm,1);
Stm.LogDensity  =   repmat(logDensity,NStm,1);
Stm.RiseTime    =   repmat(RiseTime,NStm,1);
Stm.FallTime    =   repmat(FallTime,NStm,1);

% insert randomized parameters
Stm.ISI         =	getisi(ISI,NStm);

function Stm = makeDRCstm(Par)
    
Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);
Nrep	=	str2double(Par.STRFRepetitions);
TimeStep =   str2double(Par.STRFTimeStep);
MinToneDur  =   str2double(Par.STRFMinToneDur);
ToneDurLambda  =   str2double(Par.STRFToneDurLambda);
ToneDurCutoff  =   str2double(Par.STRFToneDurCutoff);
BlockDur=	str2double(Par.STRFBlockDur);
Spk		=	str2double(Par.STRFLocation);
Level	=	eval(Par.STRFLevel);
Freq	=	eval(Par.STRFFreqRange) * 1000; %kHz -> Hz
OctStep	=	eval(Par.STRFOctStep);
% Sparsity=	eval(Par.STRFSparsity);
ToneDensity =   eval(Par.STRFToneDensity);
Sparsity = ToneDensity*OctStep;%1/12;

Freqs	=	Freq(1) * 2.^(0:OctStep:log2(Freq(2)/Freq(1)));
numfreqs = length(Freqs);
lgth = ceil(BlockDur / TimeStep * 1000); % (s/ms)*1000
minDur = round(MinToneDur./TimeStep);
lambda = ToneDurLambda./TimeStep;
cutoff = ceil(ToneDurCutoff./TimeStep);
BlockDur = (lgth+max(cutoff)-1)*TimeStep / 1000;

% [mask, params] = STRFmakepoisstonemask(lgth, Sparsity, numfreqs, Level);
[mask, int, dur, params] = DRCMaskVarDur(lgth, Sparsity, numfreqs, Level, minDur,lambda,cutoff);

Stm = table;

%--					1					2					3					4					5					 6				 7		 8		 9	 10	--%
%--				Animal name			Set number			Penetration			Pre-Record			Duration			Post-Record			ISI		Freq	Lvl	Spk	--%
% FRA		=	[repmat(Aname,Nfl,1) repmat(Nname,Nfl,1)   repmat(Pen,Nfl,1)   repmat(PreRec,Nfl,1) repmat(Dur,Nfl,1)  repmat(PostRec,Nfl,1) nan(Nfl,1)    FLS];

NStm            = Nrep;

% insert static parameters
Stm.MouseNum	=	repmat(Aname,NStm,1);
Stm.Set         =	repmat(Nname,NStm,1);
Stm.Pen         =	repmat(Pen,NStm,1);
Stm.Freqs       =   repmat({Freqs},NStm,1);
Stm.Levels      =   repmat({Level},NStm,1);
Stm.MinToneDur  =   repmat(MinToneDur,NStm,1);
Stm.ToneDurLambda  =   repmat(ToneDurLambda,NStm,1);
Stm.ToneDurCutoff  =   repmat(ToneDurCutoff,NStm,1);
Stm.OctStep     =   repmat(OctStep,NStm,1);
Stm.Sparsity    =   repmat(Sparsity,NStm,1);
Stm.Speaker     =   repmat(Spk,NStm,1);
Stm.TimeStep    =   repmat(TimeStep,NStm,1);
Stm.Dur         =   repmat(BlockDur,NStm,1);

Stm.Mask        =   repmat({mask},NStm,1);
Stm.Onset       =   repmat({int},NStm,1);
Stm.DurMask     =   repmat({dur},NStm,1);
Stm.Params      =   repmat(params,NStm,1);

Stm.Rep         =   (1:NStm)';

function OMI = makeomistm(Par)

%Experiment info
Aname	=	str2double(Par.MouseNum);
Nname	=	str2double(Par.Set);
Pen		=	str2double(Par.Penetration);
RandomSeed	=	str2double(Par.OMIRandomSeed);

Nrep    =   1;

Nsil	=	str2double(Par.InitialOMI); % number of initial silence
Nstim	=	str2double(Par.NStim);      % number of actual stimulus

%Parameters potentially with multiple values but same within one trial
SOA_ms             =	eval(Par.SOA); %ms
StimT_ms           =	eval(Par.OMIStimDuration); %ms
OMIProbability  =   eval(Par.OMIProbability); %[0,1]
ConditionPer    =   eval(Par.OMIPeriodic); % 0 or 1

LevelStd        =	eval(Par.OMILevel); % sound intensity for Standard (stimulus #1)
SpeakerStd      =	eval(Par.OMILocation);% sound location for Standard (stimulus #1)

%Parameters not intended to have multiple values (for shuffling
FreqRangeStd	=	eval(Par.OMIFRange) * 1000; % kHz -> Hz
LevelDev        =	-Inf;   % sound intensity for Deviant (stimulus #2)
FreqRangeDev    =	0;     % sound intensity for Deviant (stimulus #2)
SpeakerDev      =	SpeakerStd; % sound location for Deviant (stimulus #2)
RiseFall        =	5e-3; % s; Rise and Fall time of stimuli
ITI             =   eval(Par.OMIITI); %s

if (any(OMIProbability == 0))
    addZero = 1; 
    OMIProbability = OMIProbability(OMIProbability ~= 0);
else
    addZero = 0; 
end

if (addZero) % zero modulation
    [zeroSOA_ms, zeroStimT_ms,zeroLevelStd, zeroSpeakerStd]	=	...
        ndgrid(SOA_ms',StimT_ms',LevelStd',SpeakerStd');
    zeroSOA_ms = zeroSOA_ms(:);
    zeroStimT_ms = zeroStimT_ms(:);
    zeroLevelStd = zeroLevelStd(:);
    zeroSpeakerStd = zeroSpeakerStd(:);
    NZero        = length(zeroSOA_ms); 
end

[SOA_ms, StimT_ms, OMIProbability, ConditionPer, LevelStd, SpeakerStd]	...
 =	ndgrid(SOA_ms',StimT_ms',OMIProbability',ConditionPer',LevelStd',SpeakerStd');

SOA_ms          =	SOA_ms(:);
StimT_ms        =	StimT_ms(:);
OMIProbability		=	OMIProbability(:);
ConditionPer	=	ConditionPer(:);
LevelStd   =   LevelStd(:);
SpeakerStd   =   SpeakerStd(:);

if (addZero) % zero modulation
   
    SOA_ms          =	[SOA_ms;    zeroSOA_ms(:)];
    StimT_ms        =	[StimT_ms;  zeroStimT_ms(:)];
    LevelStd        =   [LevelStd;  zeroLevelStd(:)];
    SpeakerStd      =   [SpeakerStd;zeroSpeakerStd(:)];

    OMIProbability	=	[OMIProbability;zeros(NZero,1)];
    ConditionPer	=	[ConditionPer;ones(NZero,1)];
end

OMI = table(SOA_ms,OMIProbability,ConditionPer,...
    StimT_ms,LevelStd,SpeakerStd);

% -- randomization of order --
OMI = randtrls(OMI,Nrep);

% -- fill in rest of parameters
NTrl = size(OMI,1);
OMI.FreqRangeStd    =   repmat({FreqRangeStd},NTrl,1);
OMI.LevelDev        =   repmat(LevelDev,NTrl,1);
OMI.SpeakerDev      =   repmat(SpeakerDev,NTrl,1);
OMI.FreqRangeDev    =   repmat({FreqRangeDev},NTrl,1);
OMI.RiseFall        =	repmat(RiseFall,NTrl,1);
OMI.ITI_s           =	repmat(ITI,NTrl,1);
OMI.RandomSeed      =	repmat(RandomSeed,NTrl,1);
OMI.RandomState      =	cell(NTrl,1);

OMI.MouseNum        =	repmat(Aname,NTrl,1);
OMI.Set             =	repmat(Nname,NTrl,1);
OMI.Pen             =	repmat(Pen,NTrl,1);

OMI = [OMI(:,end-2:end), OMI(:,1:end-3)];

%Generate Omission list
minInitialStd = 9;
minStdBeforeDev = 3;
gapSize = 1;
nroInitialOmission = Nsil;

for n = 1:NTrl
    pDev = OMI.OMIProbability(n);
    periodic = OMI.ConditionPer(n);
    freqStd = max(OMI.FreqRangeStd{n});%%???
    levStd = OMI.LevelStd(n);
    if OMI.OMIProbability > 0
        list = generate_Omission_list(Nstim, pDev,...
        minInitialStd, minStdBeforeDev, gapSize,...
        nroInitialOmission, periodic, freqStd, levStd);
        OMI.Conditions{n} = list(3,:)';
    else
        OMI.Conditions{n} = [3.*ones(nroInitialOmission,1);ones(Nstim,1)];
    end
end


function [mask, int, dur, params] = DRCMaskVarDur(lgth, sparsity, numfreqs, levels, minDur,lambda,cutoff,randstate)
% [MASK, PARAMS] = newPSTHMask(lgth, VARARGIN)
% 
% Make an amplitude pulse mask with independent pulse times
% and intensities.
%
% argument:
% lgth      : total number of times steps
%
% arguments:
% sparsity   : fraction of bins high in one frequency band 
% numfreqs   : total number of frequency bands 
% levels     : sound levels in dBSPL for each frequency component. equal
%               probability. Put duplicate entries to increase relative
%               probability of one level.
% durations  : in time steps. equal probability. Put duplicate entries to
%               increase relative probability of one duration.
% RANDSTATE  : random seed (default [], uses different seed each time)
 
% Variables.
numlevels   = length(levels);

if nargin < 6; lambda   = 0;end
if nargin < 7; cutoff   = 6*lambda;end
if nargin < 8; randstate   = [];end

% correction for sparsity
meanDur = minDur + lambda ; %
sparsity = sparsity / meanDur; % correction for duration
sparsity = sparsity /(1 - sparsity * (meanDur-1)); % correction for overlap ("deadtime")

% Set rand state.
if (~isempty(randstate))
  rng(randstate);
else
  rng('shuffle');
  randstate = rng; % get latest rng state after shuffle.
end

% Build the mask, with mask values corresponding to sound magnitudes.
% levels=(-(numlevels-1):0)*deltalevel+maxlevel; % different sound pressure levels
int = rand(lgth, numfreqs); % random number [0,1]
dur = rand(lgth, numfreqs); % random number [0,1]
maskpoints = int<=sparsity; % active freqs (probability = sparsity)
int(~maskpoints) = -Inf;    % set inactive ones to -Inf
int = int/sparsity;        % rescale remaining random numbers to [0,1]
int(maskpoints) = levels(ceil(numlevels*int(maskpoints))); % randomize sound pressure level
dur(~maskpoints) = 0;    % set inactive ones to -Inf
% dur(maskpoints) = durations(ceil(numdurs*dur(maskpoints))); % randomize sound pressure level
dur(maskpoints) = minDur+min(round(expinv(dur(maskpoints),lambda)),cutoff); % randomize sound pressure level

mask = -Inf(lgth+minDur+cutoff-1, numfreqs);
int = [int;-Inf(minDur+cutoff-1,numfreqs)];
dur = [dur;zeros(minDur+cutoff-1,numfreqs)];

for i = 1:lgth
    for f = 1:numfreqs
       if (maskpoints(i,f))
           lastpnt = min([lgth+minDur+cutoff-1,i+dur(i,f)-1]);
           mask(i:lastpnt,f) = int(i,f);
           int(i+1:lastpnt,f) = -Inf;  % kill off overlappers ("dead time")
           dur(i+1:lastpnt,f) = 0;     % kill off overlappers ("dead time")
       end
    end
end
int(lgth+1:end,:) = [];
dur(lgth+1:end,:) = [];

% Save all parameters used to generate the mask.
params.randstate    = randstate;
params.sparsity     = sparsity;
params.numfreqs     = numfreqs;
params.levels       = levels;
params.randstate    = randstate;

function Stm = makeCIstm(Par)

Aname       =	str2double(Par.MouseNum);
Nname       =	str2double(Par.Set);
Pen         =	str2double(Par.Penetration);
Speaker     =   str2double(Par.CILocation);

PreRec      =	str2double(Par.CIPreTime);
PostRec     =	str2double(Par.CIPostTime);
Nrep        =	str2double(Par.CIRepetitions);
ISI         =	str2double(Par.CIISI);

% Auditory parameters:
TFreq       =   eval(Par.CITFreq);
TLevel      =	eval(Par.CITLevel);
TRamp       =   eval(Par.CITRamp);
Gap         =   eval(Par.CIGap);

NFreqL      =	eval(Par.CINFreqL); 
NFreqH      =	eval(Par.CINFreqH); 
NLevel      =   eval(Par.CINLevel);
NRamp       =   eval(Par.CINRamp);
NTime       =   eval(Par.CINTime);

PreTone = 150; % ms
PostTone = 150; % ms
ToneDur = str2double(Par.CIStimTime); % ms
TrialDur = PreTone+ToneDur+PostTone;

% Notch
NW = 1; % 1 octave
NotchLoc = [1 2]; % location rel. to TFreq

% 1  2  3    4       5      6     7     8       9       10     11     12
% T  N  P  TFreq  TLevel  TRamp  Gap  NFreqL  NFreqH  NLevel  NRamp  NTime  Notch

Tab = {'T','N','TFreq','TLevel','TRamp','Gap',...
    'NFreqL','NFreqH','NLevel','NRamp','NTime','nfL','nfH','PreTone','ToneDur','TrialDur','PreT','PostT','ISI','Aname','Nname','Pen','Speaker'};

% --- Continuous & discontinuous tones ---- 
% Step 1 & 2: Gap = 0
% Step 3, 4 & 5: Gap = [0 56]
% Step 6: Gap = [?] (6 lengths)

index = 1; % initialize to 1

for f = 1:length(TFreq)
    for ti = 1:length(TLevel)
        for g = 1:length(Gap)
            StimM(index,:) = [1 0  TFreq(f) TLevel(ti) TRamp Gap(g) 0 0 0 0 0 0 0 PreTone ToneDur TrialDur PreRec PostRec ISI Aname Nname Pen Speaker];
            index = index + 1;  % add 1 to index
        end
    end
end

% --- Background Interrupting & Surrounding Noise ----
for ni = 1:length(NLevel)
    for sis = 1:length(NTime) % s(timulus) i(nterrupting) s(urrounding)
        StimM(index,:) = [0 1 0 0 0 0 ...
            NFreqL NFreqH NLevel(ni) NRamp(sis) NTime(sis) 0 0 PreTone ToneDur TrialDur PreRec PostRec ISI Aname Nname Pen Speaker];        
        index = index + 1;
    end
end

% --- Background Interrupting Notched Noise ----
for ni = length(NLevel)
    for sis = 1:length(NTime) % s(timulus) i(nterrupting) s(urrounding)
        for n = 1:length(NotchLoc)
            nfL = NotchLoc(n)*TFreq(f) * 2^(-0.5*NW) * 1000;
            nfH = NotchLoc(n)*TFreq(f) * 2^(0.5*NW) * 1000;
            StimM(index,:) = [0 1 0 0 0 0 ...
                NFreqL NFreqH NLevel(ni) NRamp(sis) NTime(sis) nfL nfH PreTone ToneDur TrialDur PreRec PostRec ISI Aname Nname Pen Speaker];
            index = index + 1;
        end
    end
end

% --- Continuous & discontinuous tones + Int. & Surr. Noise ----
for ni = 1:length(NLevel)
    for f = 1:length(TFreq)
        for ti = 1:length(TLevel)
            for g = 1:length(Gap)
                for sis = 1:length(NTime) % s(timulus) i(nterrupting) s(urrounding)
                    StimM(index,:) = [1 1 TFreq(f) TLevel(ti) TRamp Gap(g) ...
                        NFreqL NFreqH NLevel(ni) NRamp(sis) NTime(sis) 0 0 PreTone ToneDur TrialDur PreRec PostRec ISI Aname Nname Pen Speaker];        
                    index = index + 1;
                end
            end
        end
    end
end

% --- Discontinuous tones + Int. Notched Noise ----
NTime_notch = min(NTime);
for ni = length(NLevel) % only notched noise for highest noise intensity
    for f = 1:length(TFreq)
        for n = 1:length(NotchLoc)
            nfL = NotchLoc(n)*TFreq(f) * 2^(-0.5*NW) * 1000;
            nfH = NotchLoc(n)*TFreq(f) * 2^(0.5*NW) * 1000;
            for ti = 1:length(TLevel)
                StimM(index,:) = [1 1 TFreq(f) TLevel(ti) TRamp Gap(2) ...
                    NFreqL NFreqH NLevel(ni) NRamp(1) NTime_notch nfL nfH PreTone ToneDur TrialDur PreRec PostRec ISI Aname Nname Pen Speaker];        
                index = index + 1;
            end
        end
    end
end

% Make and randomize trial matrix (StmMtx)
StmMtx      =   array2table(StimM,'VariableNames',Tab);
Stm         =	randtrls(StmMtx,Nrep);

NStm        =   size(Stm,1);

function Out = setcitrial(hApp,RS,Par,k)
S = Par.Stm(k,:);

Fs			=	Par.Fs_stm;
logdensity  =   4000; % Hz;
Gain        =   Par.Gain;
Ref         =   Par.Ref;
RefdB		=	Ref(1,2);
DACmax		=	Ref(1,3);

[Tone,~]= mywave_tone(S,Fs,Gain,RefdB,DACmax);
[Noise,~] = mywave_noise(S,Fs,logdensity,Gain,RefdB,DACmax);
% Noise = Tone;

Snd =   Tone + Noise;

%-- Upload sound waveform & set associated tags --%
RS.WriteTagV('DataIn',0,Snd);
RS.SetTagVal('HiTime',S.TrialDur);
RS.SetTagVal('LoTime',0);
RS.SetTagVal('NPulse',1);

%-- Set recording duration --%
RecDur      =   S.PreT + S.TrialDur + S.PostT; %ms
ISI			=	S.ISI;  %ms
TotalDur	=	RecDur + ISI; %ms
TotalSamp	=	round(TotalDur * Fs / 1000);
RS.SetTagVal('TotalDur',TotalSamp);

%-- Set speakers & LED parameters --%
Spk		=	S.Speaker;

Sstr 	=	setspeaker(Spk,RS);

% -- Prepare text --
if (S.T)
    if S.Gap > 0
        tonetype = 'Disc. Tone';
    else
        tonetype = 'Cont. Tone';
    end
    if (S.N) && (S.NTime >= S.ToneDur)
        infotext = {[tonetype ' + Surr. Noise ' ]};
    elseif (S.N) && (S.NTime < S.ToneDur) && (S.nfL == 0)
        infotext = {[tonetype ' + Interr. Noise ' ]};
    elseif (S.N) && (S.NTime < S.ToneDur) && (S.nfL ~= 0)
        if (S.nfL < S.TFreq*1000)
            infotext = [{[tonetype ' + Interr. Noise, Notch at TFreq' ]},...
                {['NLevel: ' num2str(S.NLevel) ' dB SPL']}];
        elseif (S.nfL > S.TFreq*1000)
            infotext = [{[tonetype ' + Interr. Noise, Notch above TFreq' ]},...
                {['NLevel: ' num2str(S.NLevel) ' dB SPL']}];
        end
    else
        infotext = {[tonetype, ' only ' ]};
    end
else
        infotext = {[num2str(S.NTime) ' ms Noise only' ]};
end


infotext = [ infotext, {['TLevel: ' num2str(S.TLevel) ' dB SPL']}, ...
                 {Sstr}	];

hApp.StimulusTextArea.Text = infotext;

Out	=	1;

function [Tone,envelope_tone] = mywave_tone(Stmk,Fs,Gain,RefdB,DACmax)
%mywave calculates the actual soundwave.
%   It calculates the tone soundwave based on the envelope and soundwave
%   variables.
TrialEnd = Stmk.TrialDur/1000; % ms -> s Total duration of the sound signal (including silent periods before and after)
ToneDur = Stmk.ToneDur / 1000; % ms -> s Tone duration including on-,off-ramps
TRamp = Stmk.TRamp/ 1000; % ms -> s Ramps for tones on-,off-ramps and gap on-,off-ramps
Gap = Stmk.Gap / 1000; % ms -> s Gap duration including on-,off-ramps
t = 0:1/Fs:TrialEnd; % creates time vector

if Stmk.T == 0
    envelope_tone = 0;
    Tone = 0;
    
elseif Stmk.T == 1
    NEnv = round(TRamp * Fs ); 
    Tstart = round((TrialEnd/2 - ToneDur/2)*Fs);
    Tend = Tstart + round(ToneDur*Fs);
    envelope_tone = zeros(size(t));
    envelope_tone(Tstart:Tend) = envelope(ones(Tend-Tstart+1,1), NEnv);

    if Stmk.Gap ~= 0
        Gstart = round((TrialEnd/2 - Gap/2)*Fs); % start of gap on-ramp
        Gend = Gstart + round(Gap*Fs); % end of gap off-ramp
        envelope_tone(Gstart:Gend) = 1 - envelope(ones(Gend-Gstart+1,1), NEnv); % create the gap envelope between Gstart and Gend
    end

    Amp     =	getamp(Gain,Stmk.TFreq*1000,Stmk.TLevel,RefdB,DACmax);
    Tone    =   Amp.*envelope_tone.*sin(2*pi*Stmk.TFreq*1000*t);
    
else
    disp('error in Stmk.T')
    envelope_tone = 0;
    Tone = 0;
end

function [Noise,envelope_noise] = mywave_noise(Stmk,Fs,logdensity,Gain,RefdB,DACmax)
%mywave calculates the actual soundwave. 
%   It calculates the noise soundwave based on the envelope and soundwave
%   variables.

TrialEnd = Stmk.TrialDur/1000; % ms -> s Total duration of the sound signal (including silent periods before and after)
NoiseDur = Stmk.NTime/1000; % ms -> s Total duration of the noise EXCLUDING on-,off-ramps
NRamp = Stmk.NRamp/ 1000; % ms -> s Ramp duration
t = 0:1/Fs:TrialEnd; % creates time vector

if Stmk.N == 0
    envelope_noise = 0;
    Noise = 0;
    
elseif Stmk.N == 1
    NEnv = round(NRamp * Fs ); 
    Nstart = round((TrialEnd/2 - NoiseDur/2 - NRamp)*Fs);
    Nend = Nstart + round((NoiseDur+2*NRamp)*Fs);
    envelope_noise = zeros(size(t));
    envelope_noise(Nstart:Nend) = envelope(ones(Nend-Nstart+1,1), NEnv);
    
    % --- Noise generation
    FreqBand = [Stmk.NFreqL Stmk.NFreqH];
    Int = Stmk.NLevel;
    Dur = Stmk.TrialDur/1000;
    Ref = [0,RefdB,DACmax];
    guardBand = 0;
    NoiseRamp = 0;
    NotchBand = [Stmk.nfL Stmk.nfH];
    
    [mainSnd,~,~]    =   gencinoise(Fs,logdensity,FreqBand,Int,Dur,Gain,Ref,guardBand,NoiseRamp,NotchBand);

    if length(mainSnd) < length(t)
        mainSnd = [mainSnd,zeros(1,length(t)-length(mainSnd))];
    end
    Noise   =   envelope_noise.*real(mainSnd);
                 
    %---- end noise generation
    
else
    disp('error in Stmk.N')
    envelope_noise = 0;
    Noise = 0;
end

function [envelope,t] = myramp(Stm,Tvar,Fs)
%myramp calculates the envelope of the soundwave.
%   It calculates the envelope for every timewindow of the soundwave and
%   creates tones, silence and ramps.

    t = 0:1/Fs:Stm.StimT; % creates time vector
    envelope = zeros(size(t));
      
    if Stm.TRamp<0
        error('TRamp should be greater than or equal to zero')
    end
    window_ramp1 = t>=Tvar & t<Tvar+Stm.TRamp;
    window_stim  = t>=Tvar+Stm.TRamp;
    envelope(window_ramp1) = sin((t(window_ramp1)-(Tvar))/Stm.TRamp*pi/2).^2;
    envelope(window_stim)  = 1;

function [mask, params] = STRFmakepoisstonemask(lgth, sparsity, numfreqs, levels, varargin)
% [MASK, PARAMS] = STRFMAKEPOISSTONEMASK(LENGTH, VARARGIN)
% 
% Make an amplitude pulse mask with fully independent pulse times
% and intensities.
%
% Required argument:
% LENGTH    : 
%
% Variable arguments:
% SPARSITY   : fraction of bins high in one frequency band (default 1/6)
% NUMFREQS   : total number of frequency bands (default 48)     
% NUMLEVELS  : total number of intensity levels (default 10)
% MAXLEVEL   : maximum intensity level in dB SPL (default 70)
% DELTALEVEL : intensity step in dB (default 5)
% RANDSTATE  : random seed (default [], uses different seed each time)
 
% Variables.
% sparsity    = 1/6;    % fraction of bins high in one frequency band
% numfreqs    = 48;    
numlevels   = length(levels);
% maxlevel    = 70;     % dB SPL
% deltalevel  = 5;      % dB steps
randstate   = [];
 
% Set rand state.
if (~isempty(randstate))
  rng(randstate);
else
  rng('shuffle');
  randstate = rng; % get latest rng state after shuffle.
end
 
% Build the mask, with mask values corresponding to sound magnitudes.
% levels=(-(numlevels-1):0)*deltalevel+maxlevel; % different sound pressure levels
mask = rand(lgth, numfreqs); % random number [0,1]
maskpoints = mask<=sparsity; % active freqs (probability = sparsity)
mask(~maskpoints) = -Inf;    % set inactive ones to -Inf
mask = mask/sparsity;        % rescale remaining random numbers to [0,1]
mask(maskpoints) = levels(ceil(numlevels*mask(maskpoints))); % randomize sound pressure level
 
% Save all parameters used to generate the mask.
params.randstate    = randstate;
params.sparsity     = sparsity;
params.numfreqs     = numfreqs;
params.levels       = levels;
params.randstate    = randstate;

function [Snd,Pul] = setDRCtrial(hApp,RS,Par,k)
    S = Par.Stm(k,:);
    Fs = Par.Fs_stm;
    Gain = Par.Gain;
    Ref = Par.Ref;
    Freqs = S.Freqs{:};
    Mask = S.Mask{:};
    Onset = S.Onset{:};
    DurMask = S.DurMask{:};

    [Snd,Pul] = genDRC(S.TimeStep,Freqs,Onset,DurMask,Mask,Fs,S.Speaker,Gain,Ref);
    %-- Set speakers & LED parameters --%
    Spk		=	S.Speaker;
    Sstr 	=	setspeaker(Spk,RS);
    
    uDur = unique(DurMask);
    uDur = reshape(uDur(uDur ~= 0),1,[]);
    if length(uDur) > 4
        DurStr = ['ToneDurs: ' num2str(min(uDur).*S.TimeStep) '-' num2str(max(uDur).*S.TimeStep) ' ms'];
    else
        DurStr = ['ToneDurs: ' num2str(uDur.*S.TimeStep) ' ms'];
    end    
hApp.StimulusTextArea.Text = [ {['freq range: ' num2str(min(Freqs),'%.1f') ' to ' num2str(max(Freqs),'%.1f') ' Hz']}, ...
								 {DurStr}, ...
								 {['Sparsity: ' num2str(S.Sparsity) ]}, ...
								 {Sstr}	];
         
function [Snd,Pul] = genDRC(TimeStep,freqs,Onset,Durs,Mask,Fs,Spk,Gain,Ref)
    disp('Generating DRC signal...');
    
    lgth = size(Onset,1);
    
    TimeStepSamp = round(TimeStep*Fs/1000);
    maxDur = max(Durs,[],'all');
    NSamp = maxDur*TimeStepSamp;
    BlockDurSamp = (lgth+maxDur-1) * TimeStepSamp;
    GateTime = 5;
 
    % Generate pulse (for first frequency)
    Pul = reshape(repmat((Mask(:,1) > -Inf)',TimeStepSamp,1) , 1, []);

    % Generate sound
    Snd = zeros(1,BlockDurSamp);
    % staggered generation
    for j = 1:maxDur
        tempSnd = zeros(1,BlockDurSamp);
        for i = j:maxDur:lgth
%             % -- debugging --
%             if (~mod(i,50)); disp([num2str(i) ' / ' num2str(lgth) ' timestep']); end
%             % ---------------
            offset = (i - 1) * TimeStepSamp;
            levels = Onset(i,:);
            durations = Durs(i,:);
            UDur = unique(durations);
            UDur = UDur(UDur~=0);
            chord = zeros(1,NSamp);
            for d = UDur
                idx = durations == d;
                newChord = genChord(d*TimeStep,freqs(idx),levels(idx),Fs, GateTime, Spk, Gain, Ref);
                if length(newChord) < NSamp
                    newChord(end+1:NSamp) = 0;
                end
                chord = chord + newChord;
            end
            tempSnd(offset+(1:NSamp)) = chord;
        end
        Snd = Snd + tempSnd;
    end
    

    
function chord = genChord(Dur,freqs,levels,Fs, GateTime, Spk, Gain, Ref)
% generate multi-tone signal of Dur with sampling frequency Fs
% 
% INPUTS:
%   Dur         = duration in ms
%   freqs       = vector of frequencies
%   levels      = vector of levels
%   Fs          = sampling frequency
%   GateTime    = duration of cosine gate
%   Gain, Ref   = gain to apply for setup


RefdB		=	Ref(1,2);
DACmax		=	Ref(1,3);

sel			=	Gain(:,3) == Spk;
Gain		=	Gain(sel,:);

%-- Carrier time axis --%
cSamp		=	round( (Dur/1000)*Fs );		%-- # samples		--%
cTime		=	( (1:cSamp)-1 ) / Fs;		%-- Time axis [sec]	--%


Amp		=	getamp(Gain,freqs,levels,RefdB,DACmax);

chord	=	Amp * sin(2*pi*freqs'*cTime);



if( size(chord,2) > 2 )
    Nenv			=	round( GateTime * 1e-3 * Fs );
    chord			=	envelope(chord',Nenv)';
end


function [TrigTime,EndTime,terminated] = contPlay(app,Sig,Pul,NRep,bufpts)
% ContPlay loads the Signal and Pulse
if (nargin<5); bufpts = [];end
if (nargin<4 || isempty(NRep)); NRep = 1;end
    RP = app.RP{1};
    zBus = app.zBus;

    NSamp       = length(Sig);

    % -- Adjust Buffer size --
    if (isempty(bufpts))
        bufpts = floor(RP.GetTagVal('BuffSize')/2);
    end
    RP.SetTagVal('BuffSize',bufpts*2); % make sure it's an even number
    % ------------------------
    
    % -- Concatenating Sig and Pul --
    disp('Concatenating sound signal...');
    Sig = [0,repmat(Sig(:)',1,NRep)];
    Pul = repmat(Pul(:),1,NRep) ... % bit 0: repeat the pulse
          + 2 .* (ones(NSamp,1) * mod(1:NRep,2)) ... % bit 1: RepToggle
          + 4 .* (ones(NSamp,NRep)); % bit 2: SoundOn
    Pul = [0,Pul(:)'];
    % -------------------------------------------
    
    % --- Reshape signal to match Buffer size ---
    disp('Reshaping sound signal to buffer size...');
    totNSamp       = length(Sig);
    
    NewNSamp    = ceil(totNSamp/bufpts)*bufpts;
    Sig(totNSamp+1:NewNSamp) = 0;
    Pul(totNSamp+1:NewNSamp) = 0;
    Sig = reshape(Sig,bufpts,[])';
    Pul = reshape(Pul,bufpts,[])';
    
    NBlocks = size(Sig,1);
    Sig(NBlocks+1:NBlocks+2,:) = zeros(2,bufpts);
    Pul(NBlocks+1:NBlocks+2,:) = zeros(2,bufpts);
    % -------------------------------------------
    
    % Write in first two segments
    disp('Loading initial chunk to buffer...');
    RP.WriteTagV('SoundDataIn',0,Sig(1,:));
    RP.WriteTagV('SoundDataIn',bufpts,Sig(2,:));
    RP.WriteTagV('PulseDataIn',0,Pul(1,:));
    RP.WriteTagV('PulseDataIn',bufpts,Pul(2,:));
 
    RP.SetTagVal('TotalDur',totNSamp);
    
    terminated = 0;
    disp('Sound starts.');
    TrigTimes = NaT(NRep,1);
    zBus.zBusTrigB(0,1,3);
    TrigTime = datetime('now'); TrigTimes(1) = TrigTime; currRep = 1;nextRepSamp = currRep * NSamp;
    curindex=RP.GetTagVal('BuffIndex');
    % Main Looping Section
    
    app.StimulusNumArea.Text			= {[num2str(NRep) ' stimuli left']};
    drawnow;
    for i = 1:NBlocks
        if (mod(i,2)) % odd blocks
            offset = 0;
            buff = -1; % first buffer
        else
            offset = bufpts;
            buff = 1; % second buffer
        end
        
        % Wait until done playing last half
        while(i ~= NBlocks ...               % not last
              && app.STARTButton.Value == 1 ...  % not stopped
              && sign(curindex-bufpts) == buff ... % still playing
              )
            curindex=RP.GetTagVal('BuffIndex');  totindex = curindex + floor((i-1)/2)*bufpts*2;
            FracComplete		=	totindex/totNSamp;
            app.Gauge.Value		=	100*FracComplete;
            
            if totindex > nextRepSamp
                disp(['Rep ' num2str(currRep) ' played']);
                currRep = currRep + 1;
                TrigTimes(currRep) = datetime('now'); nextRepSamp = currRep * NSamp;
                
                app.StimulusNumArea.Text	= {[num2str(NRep-currRep+1) ' stimuli left']};
                TimeLeft					=  (TrigTimes(currRep) - TrigTime)/ FracComplete * (1-FracComplete);
                app.DurationTextArea.Text	= {[datestr(TimeLeft,'HH:MM:SS') ' left']};
            end
            drawnow
        end
        
        % if STOP is pressed
        if (app.STARTButton.Value == 0)
            zBus.zBusTrigB(0,2,3); disp('Terminating...'); terminated = 1; break
        end
        
        % Loads the next signal segment
        if (i ~= NBlocks)
            nextBlock = i + 2;
            RP.WriteTagV('SoundDataIn', offset, Sig(nextBlock,:));
            RP.WriteTagV('PulseDataIn', offset, Pul(nextBlock,:));
        end

        curindex=RP.GetTagVal('BuffIndex'); totindex = curindex + floor((i-1)/2)*bufpts*2;
        % Loop back to wait until done playing last half
    end
    
    while(RP.GetTagVal('Active'))
        curindex=RP.GetTagVal('BuffIndex');  totindex = curindex + floor((i-1)/2)*bufpts*2;
        if totindex > nextRepSamp;  disp(['Rep ' num2str(currRep) ' played']);  currRep = currRep + 1; TrigTimes(currRep) = datetime('now'); nextRepSamp = currRep * NSamp;end
        pause(0.05);
    end
    disp(['Rep ' num2str(currRep) ' played']);  currRep = currRep + 1; TrigTimes(currRep) = datetime('now'); 
    app.StimulusNumArea.Text			= {[num2str(NRep-currRep+1) ' stimuli left']};drawnow

    TrigTime = TrigTimes(1:end-1);
    EndTime = TrigTimes(2:end);
    
    % Stop playing
    zBus.zBusTrigB(0,2,3);
    if (~terminated)
        disp('Stimulus complete');
    end

    
function [Snd,Fs] = genamnoise(Dur,Int,Mf,Md,fLow,fHigh,useLogDen,...
                        maskBand,transTime, transDur,RiseTime,FallTime,...
                        Fs,Spk,Gain,Ref)
% [SND,FS] = GENAMNOISE
% All inputs in SI units

% -- specify default values --
if isempty(maskBand)|| fLow == fHigh ; maskBand = 0;end % 
if isempty(useLogDen) ; useLogDen = 1;end % 
if (fLow > fHigh); tF= fLow; fLow = fHigh; fHigh = tF; end
RiseFall = [RiseTime,FallTime];
if (isempty(RiseFall)); RiseFall = 5e-3;end
RiseFall = RiseFall(~isnan(RiseFall)); 

%-- Main --%

if fLow == fHigh || ((fHigh - fLow) < 2*maskBand)
    f1 = fLow;
    f2 = fHigh;
else
    f1 = fLow   +   maskBand; 
    f2 = fHigh  -   maskBand;
end

%% Derived parameters
nSamp       =   round(Fs*Dur);           % Number of samples in signal
dF          =   1/Dur;              % frequency resolution

%% Use Calibration
Gain		=	Gain(Gain(:,3)==Spk,:); % -- select speaker --
DACmax      =   Ref(1,3);
RefdB       =   Ref(1,2);

% Generate Signal
%% Select frequncy band
FF          =   0:dF:dF*(nSamp-1);  % Freq Axis

mainIdx     =   (FF >= f1) & (FF <= f2);
maskIdx     =   (FF >= fLow) & (FF <= fHigh) & ~mainIdx;

mainN       =   sum([mainIdx]);           % number of freq samples in band
maskN       =   sum([maskIdx]);       % number of freq samples in band
totalN      =   mainN + maskN;           % number of freq samples in band

%% Generate random phased spectrum
maskXX1          =   zeros(1,nSamp);   % initialize with zeros
maskXX1(maskIdx) =   exp(2*pi*rand(1,maskN)*1i); % euler form - flat spectrum
mainXX1          =   zeros(1,nSamp);   % initialize with zeros
mainXX1(mainIdx) =   exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

maskXX2          =   zeros(1,nSamp);   % initialize with zeros
maskXX2(maskIdx) =   exp(2*pi*rand(1,maskN)*1i); % euler form - flat spectrum
mainXX2          =   zeros(1,nSamp);   % initialize with zeros
mainXX2(mainIdx) =   exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

%% log vs linear power density scaling
if useLogDen
    rawRMS = rms(maskXX1+mainXX1);
    % apply pink noise scaling (1/f power density; or 1/sqrt(f) magnitude)
    maskXX1(maskIdx)  =   maskXX1(maskIdx) ./ sqrt(FF(maskIdx));
    mainXX1(mainIdx)  =   mainXX1(mainIdx) ./ sqrt(FF(mainIdx));
    % rescale total power (RMS)
    newRMS      = rms(maskXX1+mainXX1);
    scale       = rawRMS / newRMS;
    maskXX1      =   maskXX1 .* scale;
    mainXX1      =   mainXX1 .* scale;

    rawRMS = rms(maskXX2+mainXX2);
    % apply pink noise scaling (1/f power density; or 1/sqrt(f) magnitude)
    maskXX2(maskIdx)  =   maskXX2(maskIdx) ./ sqrt(FF(maskIdx));
    mainXX2(mainIdx)  =   mainXX2(mainIdx) ./ sqrt(FF(mainIdx));
    % rescale total power (RMS)
    newRMS      = rms(maskXX2+mainXX2);
    scale       = rawRMS / newRMS;
    maskXX2      =   maskXX2 .* scale;
    mainXX2      =   mainXX2 .* scale;
end
%% apply calibration
ToneSPL		=	Int - 10 * log10(totalN);	%-- Each component contributes Lvl - 10*log10(# components) to the overall level --%

maskXX1(maskIdx)      =   maskXX1(maskIdx).*getamp(Gain,FF(maskIdx),ToneSPL,RefdB,DACmax);
mainXX1(mainIdx)      =   mainXX1(mainIdx).*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

maskXX2(maskIdx)      =   maskXX2(maskIdx).*getamp(Gain,FF(maskIdx),ToneSPL,RefdB,DACmax);
mainXX2(mainIdx)      =   mainXX2(mainIdx).*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

%% generate t-domain signal

mainSnd1         =   fft(mainXX1);  % fft;
maskSnd1         =   fft(maskXX1);  % fft;
mainSnd2         =   fft(mainXX2);  % fft;
maskSnd2         =   fft(maskXX2);  % fft;
TT              =   (0:nSamp-1)./Fs;    %s; time axis vector

%% Modulate signal and scramble

% -- scrambled noise (1) --
modSnd1         =   mainSnd1 .* (1+Md*cos(2*pi*(Mf*TT)));
sideSnd1 = modSnd1 - mainSnd1;
sideXX = ifft(sideSnd1);
scramXX = sideXX .* exp(2*pi*1i*rand(size(sideXX)));
scramSide1 = fft(scramXX);
scramSnd1 = mainSnd1 + scramSide1;
Snd1 = real(scramSnd1+maskSnd1);

% -- AM noise (2) --
phi = 2*pi-acos(sqrt((1+0.5*Md^2))-1); % phi in radian [0,pi] 
    % Note: "instantaneous power" of starting phase is matched to scrambled version 
modSnd2         =   mainSnd2 .* (1+Md*cos(2*pi*(Mf*TT) + phi));
Snd2 = real(modSnd2+maskSnd2);

%% apply transition
if transTime < 0
    Snd = Snd2;
elseif transTime > 0 && isinf(transTime)
    Snd = Snd1;
else
    transIdx  = TT >= transTime & TT < transTime + transDur; % samples for transition
    nTrans  = sum(transIdx); 
    nRest   = sum(TT >= transTime + transDur);
    Snd = zeros(nSamp,1);
    Snd(TT < transTime) = Snd1(TT < transTime);
    Snd(TT >= transTime + transDur) = Snd2(nTrans+(1: nRest));
    Snd(transIdx) =   Snd2(1:nTrans).* sin(0.5*pi*(1:nTrans)./nTrans)... %sine (fade-in)
        +  Snd1(transIdx) .* cos(0.5*pi*(1:nTrans)./nTrans); %cosine (fade-out)]
end
Snd = Snd(:)'; % make sure Snd is a row vector (required for TDT)


%% -- Apply envelope --%
if( size(Snd,2) > 2 )
    if ~all(RiseFall == 0)
        Nenv			=	round( RiseFall .*Fs );
        Snd				=	envelope(Snd',Nenv)';
    end
end

function FRA = FRAOnline(hApp,Par)
    SpkCounts = getspkcounts(hApp);
    nClu = size(SpkCounts,2);
    nStim = size(SpkCounts,1);
    Stm = Par.Stm;
    UInt = unique(Par.Stm.Intensity);
    UFreq = unique(Par.Stm.Freq);
    NInt = length(UInt); NFreq = length(UFreq);
    % calculating
    FRA = nan(NInt,NFreq,nClu);    
    for i = 1:NInt
        for f = 1:NFreq
            sel = Stm.Freq(1:nStim) == UFreq(f) & Stm.Intensity(1:nStim) == UInt(i);
            NTrial(i,f) = sum(sel);
            if NTrial(i,f) > 0
                FRA(i,f,:) = mean(SpkCounts(sel,:),1);
            end
        end
    end
    % ploting 
    for clu = 1:nClu
        ax(clu) = subplot(2,4,clu,'Parent',hApp.hOA);cla(ax(clu));
        CData = FRA(:,:,clu);
        imagesc(ax(clu),CData,'AlphaData',~isnan(CData),[0,Inf]);
        title(ax(clu),['C' num2str(clu)]);
        xlabel(ax(clu),'frequency (kHz)')
        ylabel(ax(clu),'intensity (dB SPL)')
        cb = colorbar(ax(clu),'eastoutside');
        cb.Label.String = '# Spikes / Stim';
    end
    linkaxes(ax);
    FreqStep = round(1/str2num(Par.FRAOctStep));
    FreqIndices = 2:FreqStep:NFreq;
    IntIndices = find(mod(UInt,10) == 0);
        set(ax,'Xscale','lin','YDir','normal',...
        'FontName','Arial','FontWeight','bold',... 'FontSize',12, ...
        'XTick',FreqIndices,'XTickLabel',round(UFreq(FreqIndices),1), 'XTickLabelRotation',45,...
        'YTick',IntIndices,'YTicklabel',UInt(IntIndices));
  

    
    
    
function SpkCounts = getspkcounts(hApp)
    RS = hApp.RP{1};
    nCh = RS.GetTagVal('nCh');
    StimIndex = RS.GetTagVal('StimIndex');
    SpkCounts = RS.ReadTagVEX('SpkCounts',0,StimIndex/nCh,'I32','F64',nCh)';

function [som_waveform,tt] = gensomwaveform(Waveform,StimDur,Amplitude,SomFreq,Ramp,Fs)
    StimDurSamp = ceil(StimDur * 0.001 * Fs);
    som_waveform = nan(1,StimDurSamp);
    tt = 0:1/Fs:(StimDur* 0.001);
    switch Waveform
        case {'Square'}
            som_waveform = Amplitude .* ones(1,StimDurSamp);
            som_waveform(1) = 0; som_waveform(end) = 0; % zero at beginning or end
        case {'UniSine'}
            som_waveform =  0.5 * Amplitude .* ( 1-cos(2*pi*SomFreq .* tt) );
        case {'BiSine'}
            som_waveform =  Amplitude .* ( sin(2*pi*SomFreq .* tt) );
    end

    % apply envelope (On-/Off-ramps)
    if Ramp > 0
        Nenv			=	round( Ramp * 10^-3 * Fs );
	    som_waveform    =	envelope(som_waveform',Nenv)';
    end


function [stimulus,t,index_first_stimulus] = square_stimulus(fs,hApp)
    %Get the parameters
    Par = getparams(hApp);
    SomDurs = str2double(Par.SomatosensoryStimTime);
    ISI = str2double(Par.SomatosensoryISI);
    A = str2num(Par.SomatosensoryAmplitude);
    Nrep = str2double(Par.SomatosensoryRepetitions);
    ISI=ISI*1e-3; %s
    SomDurs=SomDurs*1e-3; %s
    
    %Calculate the total duration of the stimulus
    duration = Nrep*length(A)*ISI; %s
    dt = 1/fs;
    t = 0:dt:duration;
    stimulus = zeros(size(t));
    
    %Limit to 5 the number of displayed pulses
    if length(A)>5
        index_first_stimulus=ISI*5*fs; 
        message = "Only the first 5 amplitude values will be displayed! ";
        uialert(hApp.UIFigure,message,"Warning","Icon","warning");
    else
        index_first_stimulus=ISI*length(A)*fs;
    end
    
 
    %Generate the stimulus waveform 
    j=1;
    for rep = 1:Nrep
        for i = 2:length(t)
            if mod(t(i-1), ISI) < SomDurs
                stimulus(i) = A(j);
            end
            if mod(t(i), ISI) == 0 && t(i) ~= 0
                j = j+1;
                if j>length(A)
                    j=1; 
                end
            end
        end
    end

function [stimulus,t,index_first_stimulus] = bi_sinusoidal_stimulus(fs,hApp)
    %Get the parameters
    Par = getparams(hApp);
    SomDurs = str2double(Par.SomatosensoryStimTime);
    ISI = str2double(Par.SomatosensoryISI);
    A = str2num(Par.SomatosensoryAmplitude);
    Nrep = str2double(Par.SomatosensoryRepetitions);
    f = str2double(Par.SomatosensoryFrequency);
    ISI=ISI*1e-3; %s
    SomDurs=SomDurs*1e-3; %s
    offset=5;
    
    %Calculate the total duration of the stimulus
    duration = Nrep*length(A)*ISI; %s
    dt = 1/fs; 
    t = 0:dt:duration;
    stimulus = zeros(size(t)); 

    %Limit to 5 the number of displayed pulses
    if length(A)>5
        index_first_stimulus=ISI*5*fs; 
        message = "Only the first 5 amplitude values will be displayed! ";
        uialert(hApp.UIFigure,message,"Warning","Icon","warning");
    else
        index_first_stimulus=ISI*length(A)*fs;
    end
    
    %Generate the stimulus waveform 
    j=1;
    for rep = 1:Nrep
        for i = 1:length(t)
            if mod(t(i), ISI) < SomDurs
                stimulus(i) = offset + A(j)/2*sin(2*pi*f*t(i));
            else
                stimulus(i) = offset;
            end
            if mod(t(i), ISI) == 0 && t(i) ~= 0
                j = j+1;
                if j>length(A)
                    j=1; 
                end
            end
        end
    end

function [stimulus,t,index_first_stimulus] = uni_sinusoidal_stimulus(fs,hApp)
    %Get the parameters
    Par = getparams(hApp);
    SomDurs = str2double(Par.SomatosensoryStimTime);
    ISI = str2double(Par.SomatosensoryISI);
    A = str2num(Par.SomatosensoryAmplitude);
    Nrep = str2double(Par.SomatosensoryRepetitions);
    f = str2double(Par.SomatosensoryFrequency);
    ISI=ISI*1e-3; %s
    SomDurs=SomDurs*1e-3; %s    

    %Calculate the total duration of the stimulus
    duration = Nrep*length(A)*ISI; %s
    dt = 1/fs;  
    t = 0:dt:duration;
    stimulus = zeros(size(t)); 

    %Make sure that the frequency is such that allows for complete sinusoidal waves
    if mod(f,1/SomDurs)~=0
        message = ["The frequency must be a multiple of",1/SomDurs];
        uialert(hApp.UIFigure,message,"Warning","Icon","warning");
    end

    %Limit to 5 the number of displayed pulses
    if length(A)>5
        index_first_stimulus=ISI*5*fs; 
        message = "Only the first 5 amplitude values will be displayed!";
        uialert(hApp.UIFigure,message,"Warning","Icon","warning");
    else
        index_first_stimulus=ISI*length(A)*fs;
    end
    
    %Generate the stimulus waveform 
    j=1;
    for rep = 1:Nrep
        for i = 1:length(t)
            if mod(t(i), ISI) < SomDurs
                stimulus(i) = A(j)/2 + A(j)/2*sin(2*pi*f*t(i)-pi/2);
            else
                stimulus(i) = 0;
            end
            if mod(t(i), ISI) == 0 && t(i) ~= 0
                j = j+1;
                if j>length(A)
                    j=1;
                end
            end
        end
    end

function out = msgOpenEphys(msg)
    % wrapper function to send a message to Open Ephys GUI using their
    % built-in HTTP server functionality
    url = 'http://localhost:37497/api/message';
    try
        out = webwrite(url, struct('text',msg), ...
            weboptions('RequestMethod','put','MediaType','application/json'));

        if strcmp(out.mode,'RECORD'); disp('OpenEphysGUI is recording.');
        else;  warning('OpenEphysGUI is not recording.');
        end
    catch
        warning('Error communicating with OpenEphyGUI.')
    end