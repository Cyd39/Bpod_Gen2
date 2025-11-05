function plotraster_behavior(Session_tbl)
    
    fig = figure;clf(fig);
    
    n_trial = height(Session_tbl);

    % loop through trials
    t_min = 0;
    t_max = 0;
    
    for i_ax = 1:2
        ax = subplot(1,2,i_ax); hold(ax,'on');
        for idx = 1:n_trial
            pos = idx;
    
            tempLeftLicks = Session_tbl.LeftLickOn{idx};
            tempRightLicks = Session_tbl.RightLickOn{idx};
    
            tempLeftReward = Session_tbl.LeftReward(idx,1);
            tempRightReward = Session_tbl.RightReward(idx,1);
    
            trial_start = 0;
            trial_end = Session_tbl.WaitToFinish(idx,2);
            
            % align to stimulus onset
            StimOnset = Session_tbl.Stimulus(idx,1);
            tempLeftLicks = tempLeftLicks - StimOnset;
            tempRightLicks = tempRightLicks - StimOnset;
            tempLeftReward = tempLeftReward - StimOnset;
            tempRightReward = tempRightReward - StimOnset;
            trial_start = trial_start - StimOnset;
            t_min = min(t_min,trial_start);
            trial_end = trial_end - StimOnset;
            t_max = max(t_max,trial_end);
            
            plot(ax, [trial_start,trial_end],[pos,pos],'-','Color',[.7,.7,.7]);    
    
            plot(ax, tempLeftLicks,pos.*ones(size(tempLeftLicks)),'.','Color',[0.2 0.2 1]);    
            plot(ax, tempRightLicks,pos.*ones(size(tempRightLicks)),'.','Color',[1 0.2 0.2]);    
    
            plot(ax, tempLeftReward,pos,'s','MarkerFaceColor',[0.2 0.2 1],'Color',[0.2 0.2 1]);    
            plot(ax, tempRightReward,pos,'s','MarkerFaceColor',[1 0.2 0.2],'Color',[1 0.2 0.2]); 

    
        end

        ylabel('Trial number')
        xlabel('Time re stim. onset (s)')
        ylim([0.2,n_trial+0.8]);

        switch i_ax
            case 1
                xlim(ax, [t_min-0.1, t_max]);
            case 2
                xlim(ax, [-.55,1])
        end
    end
end