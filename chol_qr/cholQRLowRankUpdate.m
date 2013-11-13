function [k , kadv, delta, P, G, Q, R, Dadv, QGG, infoQ, infoR, D, usedInfoPInds] ...
                                    = cholQRLowRankUpdate(  size_params, ...
                                                            trainx,...
                                                            K,...
                                                            P,...
                                                            G,...
                                                            Q,...
                                                            R,...
                                                            Dadv,...
                                                            QGG,...
                                                            infoQ,...
                                                            infoR,...
                                                            noise_var,...
                                                            D, ...
                                                            usedInfoPInds)
                                                  
DEBUG = false;


assert(all(D>=0));
assert(all(Dadv>=0));

if ~exist('usedInfoPInds','var')
    usedInfoPInds = [];
end

ik_best = size_params.ik_best;
k = size_params.k;
n = size_params.n;
kadv = size_params.kadv;
delta = size_params.delta;
                                                                    
if ik_best > kadv
    %the selected pivot is not among the look ahead ones
    %need to do Cholesky with it and pivot it to position kadv+1
    D_ik_best = Dadv(ik_best);
    new_pivot = ik_best; 
    ik_best = kadv + 1; %after Chol update and pivoting, it will be at kadv+1
else
    %the selected pivot is among the look ahead ones, just pick a
    %replacement one for it using max diag criteria
%     [D_ik_best, new_pivot] = max(Dadv(k:end));
%     new_pivot = new_pivot + k - 1;
    [new_pivot, D_ik_best] = getMaxInd(Dadv,kadv);
end

if D_ik_best < 1e-10
%     notes = [notes sprintf(['Look-ahead decomposition failed' ... 
%         'due to numerical problem at step %d,'...
%         'selecting pivot for numerical stability' ... 
%         'not for objective function reduction ;\t'],k)];
% 
%     %need to pick one from the look-ahead portion to permute to
%     %position k now
%     diagL = sum(G(k:kadv,k:kadv).^2,2);
%     [~, ik_best] = max(diagL);
%     ik_best = ik_best + k - 1;
%     delta = delta - 1;
    error('numerically unstable');
else
    kadv = kadv + 1;
 

    [P, G, Dadv, D, usedInfoPInds, Q] = cholOneStep(  new_pivot , ...
                                                    kadv,...
                                                    trainx,...
                                                    K, ...
                                                    P, ...
                                                    G, ...
                                                    Dadv, ...
                                                    noise_var,...
                                                    D, usedInfoPInds, Q);
    if ~isempty(QGG)
     [QGG, infoQ, infoR] = updateCacheOneStep(  new_pivot , ...
                                                kadv, ...
                                                k, ...
                                                n, ...
                                                G(:,kadv), ...
                                                Q, ...
                                                QGG, ...
                                                infoQ, ...
                                                infoR);  
    end
    
end

[P, G, Q, R, Dadv, QGG, infoQ, infoR, D, usedInfoPInds] = cholQRPermuteUpdate( ...
                                                    struct('dst_ind', k, ...
                                                           'src_ind', ik_best, ...
                                                           'kbound', kadv, ...
                                                           'n', n), ...
                                                            P, ...
                                                            G, ...
                                                            Q, ...
                                                            R, ...
                                                            Dadv, ...
                                                            QGG, ...
                                                            infoQ, ...
                                                            infoR, ...
                                                            D, ...
                                                            usedInfoPInds);
if ~isempty(QGG)
    QGG = QGG - (Q(1:n, 1:k-1).'*G(1:n, k))*(G(1:n,k).');                                
    QGG = [QGG; (Q(1:n,k).'*G(1:n, k+1:kadv))*G(1:n,k+1:kadv).'];
end

if DEBUG  
    G_recon = Q(:,1:k)*R(1:k,1:k);
    [has_err] = test_matrix_same(G_recon, G(:,1:k),'G');
    assert(~has_err);
end


if ~isempty(infoQ)
    [infoQ,infoR] = qrdelete(infoQ, infoR, 1, 'col');
end

k = k + 1;
assert(all(D>=0));
assert(all(Dadv>=0));

end