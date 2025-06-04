% === 참값: nasa data : (STK 기반) ===
stk_filename = 'Truth_Orbit_State_Vector.csv';
opts = detectImportOptions(stk_filename, 'VariableNamingRule', 'preserve');
opts = setvartype(opts, 'char');
stk_data = readtable(stk_filename, opts);

time_strings_stk = strtrim(stk_data{:, 1});
try_formats = {
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd hh:mm:ss a',
    'dd MMM yyyy HH:mm:ss.SSS',
    'dd MMM yyyy HH:mm:ss'
};
t_utc = NaT(size(time_strings_stk));
for k = 1:length(try_formats)
    try
        t_utc_try = datetime(time_strings_stk, 'InputFormat', try_formats{k}, 'Locale', 'en_US', 'TimeZone', 'UTC');
        if all(~isnat(t_utc_try))
            t_utc = t_utc_try;
            fprintf('✅ 적용된 STK 포맷: %s\n', try_formats{k});
            break;
        end
    catch
        continue;
    end
end
if any(isnat(t_utc))
    warning('STK 시간 형식이 반응되지 않음. 값을 확인해주세요.');
end

stk_unix_time = posixtime(t_utc);
navPos = str2double(stk_data{:, 2:4});

% === 예측값: TLE 전파값 (matlab SPG4) ===
nasa_filename = 'satellite_state_vectors.csv';
opts2 = detectImportOptions(nasa_filename, 'VariableNamingRule', 'preserve');
opts2 = setvartype(opts2, 'char');
nasa_data = readtable(nasa_filename, opts2);

rel_time_str = strtrim(nasa_data{:, 1});
try_formats_tle = {
    'dd MMM yyyy HH:mm:ss.SSS',
    'dd MMM yyyy HH:mm:ss'
};
tle_utc = NaT(size(rel_time_str));
for k = 1:length(try_formats_tle)
    try
        tle_try = datetime(rel_time_str, 'InputFormat', try_formats_tle{k}, 'Locale', 'en_US', 'TimeZone', 'UTC');
        if all(~isnat(tle_try))
            tle_utc = tle_try;
            fprintf('✅ 적용된 TLE 포맷: %s\n', try_formats_tle{k});
            break;
        end
    catch
        continue;
    end
end
if any(isnat(tle_utc))
    warning('TLE 예측 시간 형식 무효.');
end
nasa_unix_time = posixtime(tle_utc);

% 위치 열 확인
varnames = nasa_data.Properties.VariableNames;
xyz_idx = find(contains(lower(varnames), {'x', 'y', 'z'}));
xyz_idx = xyz_idx(1:3);
nasaPos = str2double(nasa_data{:, xyz_idx});

% === 시간 복정 일치 ===
tol = 0.5;
[common_time, stk_idx, nasa_idx] = find_common_time(stk_unix_time, nasa_unix_time, tol);
XL_all = navPos(stk_idx, :);
Xerr_all = nasaPos(nasa_idx, :) - XL_all;
t_common_utc = t_utc(stk_idx);  % 매칭된 UTC 시간

% === OURE 계산 ===
N = length(common_time);
oure_wl_all = zeros(N, 1);
fprintf('\n--- OURE 계산 로그 ---\n');
for i = 1:N
    tstr = datetime(common_time(i), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    tstr_fmt = datestr(tstr, 'yyyy-mm-dd HH:MM:SS.FFF');
    
    oure_val = calc_OURE_wl_precise(XL_all(i,:)', Xerr_all(i,:)');
    oure_wl_all(i) = oure_val;

    fprintf('[%03d] %s → OURE_wl = %.3f m\n', i, tstr_fmt, oure_val);
end


outfile = ['OURE_results_' datestr(now, 'yyyymmdd_HHMM') '.csv'];
writematrix([common_time, oure_wl_all], outfile);

plot(t_common_utc, oure_wl_all); grid on;
xlabel('UTC Time'); ylabel('OURE_{wl} (m)');
title('Worst-Case OURE over Time');

[max_oure, max_idx] = max(abs(oure_wl_all));
rms_oure = sqrt(mean(oure_wl_all.^2));

fprintf('\n\n🔹 Worst-case OURE_wl = %.3f m at index %d (UTC Time = %s)\n', max_oure, max_idx, string(t_common_utc(max_idx)));
fprintf('🔸 RMS OURE_wl = %.3f m\n', rms_oure);

% === URA 계산 (p = 1e-5) ===
p = 1e-5;
C_inv = @(p) sqrt(2) * erfinv(2 * p - 1);  % 정규분포 역함수 대체
z_p = C_inv(1 - p/2);
oura = rms_oure / z_p;

fprintf('🔸 URA (%.1e integrity risk) = %.3f m\n', p, oura);

% === OURE 계산 함수 ===
function oure_wl = calc_OURE_wl_precise(XL, Xerr)
    f = 1 / 298.257222101;
    a = 6378137.0;
    e2 = 2*f - f^2;

    xL = XL(1); yL = XL(2); zL = XL(3);
    xerr = Xerr(1); yerr = Xerr(2); zerr = Xerr(3);

    beta2 = (xerr^2 + yerr^2)/(a^2 * zerr^2) + 1/(a^2 * (1 - f)^2);
    beta1 = (2 / (a^2 * zerr)) * (xerr * (xL - (xerr * zL / zerr)) + yerr * (yL - (yerr * zL / zerr)));
    beta0 = ((zerr * xL - xerr * zL)^2 + (zerr * yL - yerr * zL)^2) / (a^2 * zerr^2) - 1;
    D = beta1^2 - 4 * beta2 * beta0;

    if D >= 0
        dotprod = dot(XL, Xerr);
        oure_wl = sign(dotprod) * norm(Xerr);
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

            b1 = yL;
            b2 = xL;
            b3 = a * sqrt(1 - e2 * sin_phi^2) / cos_phi - tan(phi) * zL;

            lambda = asin(b3 / sqrt(b1^2 + b2^2)) - atan2(b2, b1);

            cos_lambda = cos(lambda);
            sin_lambda = sin(lambda);
            xT = N_phi * cos_phi * cos_lambda;
            yT = N_phi * cos_phi * sin_lambda;
            zT = N_phi * (1 - e2) * sin_phi;
            XT = [xT; yT; zT];

            vec1 = (XL - XT) / norm(XL - XT);
            vec2 = Xerr / norm(Xerr);
            cos_theta = dot(vec1, vec2);
            if abs(cos_theta) > abs(max_cos_theta)
                max_cos_theta = cos_theta;
            end
        end
        oure_wl = norm(Xerr) * abs(max_cos_theta);
    end
end

% === 시간 복정 일치 함수 ===
function [common_time, stk_idx, nasa_idx] = find_common_time(t1, t2, tol)
    stk_idx = [];
    nasa_idx = [];
    for i = 1:length(t1)
        dt = abs(t2 - t1(i));
        [dmin, idx] = min(dt);
        if dmin <= tol
            stk_idx(end+1) = i;
            nasa_idx(end+1) = idx;
        end
    end
    common_time = t1(stk_idx);
end
