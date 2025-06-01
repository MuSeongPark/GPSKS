% === 참값: (Nasa data 기반) ===
truth_filename = '06010630Truth_Orbit_State_Vector.csv';
opts = detectImportOptions(truth_filename, 'VariableNamingRule', 'preserve');
opts = setvartype(opts, 'char');
truth_data = readtable(truth_filename, opts);

time_strings_truth = strtrim(truth_data{:, 1});
try_formats = {
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd hh:mm:ss a',
    'dd MMM yyyy HH:mm:ss.SSS',
    'dd MMM yyyy HH:mm:ss'
};
truth_utc = NaT(size(time_strings_truth));
for k = 1:length(try_formats)
    try
        utc_try = datetime(time_strings_truth, 'InputFormat', try_formats{k}, 'Locale', 'en_US', 'TimeZone', 'UTC');
        if all(~isnat(utc_try))
            truth_utc = utc_try;
            fprintf('✅ 적용된 참값 포맷: %s\n', try_formats{k});
            break;
        end
    catch
        continue;
    end
end
if any(isnat(truth_utc))
    warning('STK 시간 형식이 반응되지 않음. 값을 확인해주세요.');
end

truth_unix_time = posixtime(truth_utc);
truth_pos = str2double(truth_data{:, 2:4});

% === 예측값: TLE 전파값 ===
pred_filename = '2018.06.01~06.31_TLE.csv';
opts2 = detectImportOptions(pred_filename, 'VariableNamingRule', 'preserve');
opts2 = setvartype(opts2, 'char');
pred_data = readtable(pred_filename, opts2);

time_strings_pred = strtrim(pred_data{:, 1});
try_formats_pred = {
    'dd MMM yyyy HH:mm:ss.SSS',
    'dd MMM yyyy HH:mm:ss'
};
pred_utc = NaT(size(time_strings_pred));
for k = 1:length(try_formats_pred)
    try
        utc_try = datetime(time_strings_pred, 'InputFormat', try_formats_pred{k}, 'Locale', 'en_US', 'TimeZone', 'UTC');
        if all(~isnat(utc_try))
            pred_utc = utc_try;
            fprintf('✅ 적용된 TLE 포맷: %s\n', try_formats_pred{k});
            break;
        end
    catch
        continue;
    end
end
if any(isnat(pred_utc))
    warning('TLE 예측 시간 형식 무효.');
end

pred_unix_time = posixtime(pred_utc);
varnames = pred_data.Properties.VariableNames;
xyz_idx = find(contains(lower(varnames), {'x', 'y', 'z'}));
xyz_idx = xyz_idx(1:3);
pred_pos = str2double(pred_data{:, xyz_idx});

tol = 0.5;
[common_time, truth_idx, pred_idx] = find_common_time(truth_unix_time, pred_unix_time, tol);
truth_common_pos = truth_pos(truth_idx, :);
error_vec = pred_pos(pred_idx, :) - truth_common_pos;
common_utc = truth_utc(truth_idx);

N = length(common_time);
oure_wl_all = zeros(N, 1);
case_all = strings(N, 1);
ric_all = zeros(N, 3);
dot_all = zeros(N, 1);

fprintf('\n--- OURE 계산 로그 ---\n');
for i = 1:N
    tstr = datetime(common_time(i), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    tstr_fmt = datestr(tstr, 'yyyy-mm-dd HH:MM:SS.FFF');

    [oure_val, case_type] = calc_OURE_wl_precise_verbose(truth_common_pos(i,:)', error_vec(i,:)');
    oure_wl_all(i) = oure_val;
    case_all(i) = case_type;

    ric_vec = get_RIC_error(truth_common_pos(i,:)', pred_pos(pred_idx(i), :)');
    ric_all(i, :) = ric_vec';
    dot_all(i) = dot(truth_common_pos(i,:)', error_vec(i,:)');

    fprintf('[%03d] %s → OURE_wl = %.3f m (Case %s) | RIC = [%.3f %.3f %.3f] m\n', ...
        i, tstr_fmt, oure_val, case_type, ric_vec(1), ric_vec(2), ric_vec(3));
end

outfile = ['OURE_results_' datestr(now, 'yyyymmdd_HHMM') '.csv'];
writematrix([common_time, oure_wl_all, ric_all], outfile);

plot(common_utc, oure_wl_all); grid on;
xlabel('UTC Time'); ylabel('OURE_{wl} (m)');
title('Worst-Case OURE over Time');

figure;
histogram(oure_wl_all, 50);
title('Histogram of OURE_{wl}');
xlabel('OURE_{wl} (m)'); ylabel('Count');

dot_cos = dot_all ./ (vecnorm(truth_common_pos, 2, 2) .* vecnorm(error_vec, 2, 2));
figure;
histogram(dot_cos, 50);
title('Histogram of cos(\theta) between Truth and Error');
xlabel('cos(\theta)'); ylabel('Count');

figure;
histogram(ric_all(:,1), 50); title('Histogram of Radial Error'); xlabel('Radial (m)');
figure;
histogram(ric_all(:,2), 50); title('Histogram of In-track Error'); xlabel('In-track (m)');
figure;
histogram(ric_all(:,3), 50); title('Histogram of Cross-track Error'); xlabel('Cross-track (m)');

[max_oure, max_idx] = max(abs(oure_wl_all));
rms_oure = sqrt(mean(oure_wl_all.^2));

fprintf('\n\n🔹 Worst-case OURE_wl = %.3f m at index %d (UTC Time = %s)\n', ...
    max_oure, max_idx, string(common_utc(max_idx)));
fprintf('🔸 RMS OURE_wl = %.3f m\n', rms_oure);

p = 1e-5;
C_inv = @(p) sqrt(2) * erfinv(2 * p - 1);
z_p = C_inv(1 - p/2);
oura = rms_oure / z_p;

fprintf('🔸 URA (%.1e integrity risk) = %.3f m\n', p, oura);

function [oure_wl, case_type] = calc_OURE_wl_precise_verbose(truth_pos, error_vec)
    f = 1 / 298.257222101;
    a = 6378137.0;
    e2 = 2*f - f^2;

    x_t = truth_pos(1); y_t = truth_pos(2); z_t = truth_pos(3);
    dx = error_vec(1); dy = error_vec(2); dz = error_vec(3);

    beta2 = (dx^2 + dy^2)/(a^2 * dz^2) + 1/(a^2 * (1 - f)^2);
    beta1 = (2 / (a^2 * dz)) * (dx * (x_t - (dx * z_t / dz)) + dy * (y_t - (dy * z_t / dz)));
    beta0 = ((dz * x_t - dx * z_t)^2 + (dz * y_t - dy * z_t)^2) / (a^2 * dz^2) - 1;
    D = beta1^2 - 4 * beta2 * beta0;

    if D >= 0
        dotprod = dot(truth_pos, error_vec);
        oure_wl = sign(dotprod) * norm(error_vec);
        case_type = 'A';
    else
        max_cos_theta = -1;
        for phi_deg = -90:0.1:90
            phi = deg2rad(phi_deg);
            cos_phi = cos(phi);
            if abs(cos_phi) < 1e-6
                continue;
            end
            sin_phi = sin(phi);
            N_phi = a / sqrt(1 - e2 * sin_phi^2);

            b1 = y_t;
            b2 = x_t;
            b3 = a * sqrt(1 - e2 * sin_phi^2) / cos_phi - tan(phi) * z_t;

            lambda = asin(b3 / sqrt(b1^2 + b2^2)) - atan2(b2, b1);

            cos_lambda = cos(lambda);
            sin_lambda = sin(lambda);
            x_proj = N_phi * cos_phi * cos_lambda;
            y_proj = N_phi * cos_phi * sin_lambda;
            z_proj = N_phi * (1 - e2) * sin_phi;
            proj_pos = [x_proj; y_proj; z_proj];

            vec_truth_to_surface = (truth_pos - proj_pos) / norm(truth_pos - proj_pos);
            vec_error_dir = error_vec / norm(error_vec);
            cos_theta = dot(vec_truth_to_surface, vec_error_dir);
            if abs(cos_theta) > abs(max_cos_theta)
                max_cos_theta = cos_theta;
            end
        end
        oure_wl = norm(error_vec) * abs(max_cos_theta);
        case_type = 'B';
    end
end

function [common_time, truth_idx, pred_idx] = find_common_time(t1, t2, tol)
    truth_idx = [];
    pred_idx = [];
    for i = 1:length(t1)
        dt = abs(t2 - t1(i));
        [dmin, idx] = min(dt);
        if dmin <= tol
            truth_idx(end+1) = i;
            pred_idx(end+1) = idx;
        end
    end
    common_time = t1(truth_idx);
end

function ric = get_RIC_error(r_truth, r_pred)
    r_hat = r_truth / norm(r_truth);
    v_dummy = cross([0; 0; 1], r_truth);
    h = cross(r_truth, v_dummy);
    c_hat = h / norm(h);
    i_hat = cross(c_hat, r_hat);
    dR = r_pred - r_truth;
    ric = [dot(dR, r_hat); dot(dR, i_hat); dot(dR, c_hat)];
end
