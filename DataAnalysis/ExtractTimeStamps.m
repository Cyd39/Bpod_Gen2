function Session_tbl = ExtractTimeStamps(SessionData)

% Session Data
Session_struct = [SessionData.RawEvents.Trial{:}];

% States 
Session_states = [Session_struct.States];
Session_state_tbl = struct2table(Session_states);


%%
events_to_store = {'BNC1High','BNC1Low'};
event_labels = {'LickOn','LickOff'};
% events_to_store: cell array of field names to extract

num_C = numel(Session_struct);
num_fields = numel(events_to_store);

% Preallocate output
out = cell(num_C, num_fields);

for idx = 1:num_C
    for j = 1:num_fields
        fname = events_to_store{j};
        if isfield(Session_struct(idx).Events, fname)
            out{idx, j} = Session_struct(idx).Events.(fname);
        else
            out{idx, j} = NaN;
        end
    end
end
Session_tbl = [SessionData.StimTable, Session_state_tbl, cell2table(out, 'VariableNames', event_labels)];
end
