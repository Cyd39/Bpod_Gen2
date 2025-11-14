% DecideWhichSide function
% This function is used to decide which side the animal should be trained on in the next trial
% Input: SessionData - the session data
%        NumRunningAvg - the number of running average trials to use for the decision
% Output: side - the side the animal should be trained on in the next trial
function side = DecideWhichSide(SessionData,NumRunningAvg)
