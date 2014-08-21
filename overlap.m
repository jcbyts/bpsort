% Test harness using synthetic data

rng(1)
T = 1;        % min
K = 3;          % channels
M = 2;          % single units
Fs = 12000;     % Hz
N = T * 60 * Fs;
sd = 7;         % noise SD
refrac = 2;     % ms refractory period 
rate = 50;      % spikes/s

% generate waveforms
spike = [0 10 18 10 -25 -60 -35 -11 0 7 10 12 13 13 12 10 7 3 1 0]';
spike = spike / norm(spike);
D = numel(spike);

Wt = spike * [1 2 1];
Wt(:, :, 2) = Wt + 0.3 * [spike(2 : D); 0] * [1 -1 0] ...
                 + 0.3 * [0; spike(1 : D - 1)] * [0 1 -1];
Wt = 35 * Wt;

% add spikes
V = randn(N, K) * sd;
[~, peak] = min(spike);
ndx = (1 : numel(spike)) - peak;
spikes = cell(1, M);
for i = 1 : M
    s = peak + find(rand(N - numel(spike), 1) < rate / Fs);
    viol = diff(s) < refrac / 1000 * Fs;
    while any(viol)
        s(viol) = [];
        viol = diff(s) < refrac / 1000 * Fs;
    end
    for j = 1 : numel(s)
        V(s(j) + ndx, :) = V(s(j) + ndx, :) + Wt(:, :, i);
    end
    spikes{i} = s;
end

Xt = sparse(N, M);
for i = 1 : numel(spikes)
    Xt(round(spikes{i}), i) = 1; %#ok
end


%% run initialized with ground truth
pass = [600 6000] / (Fs / 2);   % passband
bp = BP('window', [-0.4 1.2], 'Fs', Fs, 'passband', pass);
[X, W] = bp.fit(V, Xt, 3);


%% plot waveforms
smp = bp.samples;
sp = max(abs(W(:)));
c = [1 0 0; 0 0.4 1];
figure(1), clf
h(1) = subplot(121); hold on
for i = 1 : 2
    plot(smp, bsxfun(@plus, Wt(:,:,i), (1 : K) * sp), 'color', c(i, :))
end
h(2) = subplot(122); hold on
for i = 1 : 2
    plot(smp, bsxfun(@plus, W(:,:,i), (1 : K) * sp), 'color', c(i, :))
end
linkaxes(h, 'xy');
axis tight


%% plot raw trace with detected and assigned spikes
figure(2), clf
plot(bsxfun(@plus, V, (1 : K) * 100), 'k')
hold on
for i = 1 : 2
    sp = find(Xt(:, i));
    plot(sp, ones(size(sp)) * 10, '*', 'color', c(i, :), 'markersize', 20)
    sp = find(X(:, i));
    plot(sp, ones(size(sp)) * 10, 'o', 'color', c(i, :), 'markersize', 20)
end


%% Check what happens here
ii = 178630;
xlim(ii + [-1 1] * 200)


%% run mixture model to check for overlap of the two clusters
[~, s] = find(Xt');
w = extractWaveforms(V, s, smp);
% b = extractFeatures(w, 5);
% model = MixtureModel.fit(b);


%% plot overlap using ground truth
dw = diff(reshape(W, D * K, 2), [], 2);
dw = dw / norm(dw);
ww = reshape(permute(w, [1 3 2]), D * K, []);
figure(3), clf
hist(dw' * ww, 80)