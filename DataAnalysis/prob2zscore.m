function r = prob2zscore(r,n)
    if nargin<2;n=10000*ones(size(r));end
    r(r == 1) = 1 - 0.5 ./ n(r == 1);
    r(r == 0) = 0.5 ./ n(r == 0);
    r = norminv(r);
end