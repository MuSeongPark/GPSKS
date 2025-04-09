% 데이터 파일 경로
%stk_filename = 'GRACE-FO_2_43477_j2000.csv';
stk_filename = 'GRACE-FO_2_43477_Fixed_Position_Velocity.csv';

% 파일 옵션 설정: 모든 열을 문자열로 먼저 불러오기
opts = detectImportOptions(stk_filename);
opts = setvartype(opts, 'char');
stk_data = readtable(stk_filename, opts);

% UTC 기준 시간 문자열을 datetime으로 변환
datetime_format = 'dd MMM yyyy HH:mm:ss.SSS'; 
time_strings = stk_data{:,1};
t_utc = datetime(time_strings, 'InputFormat', datetime_format, ...
                 'Locale', 'en_US', 'TimeZone', 'UTC');

% Unix Time 변환
stk_unix_time = posixtime(t_utc);

% Position 데이터 (x, y, z) 추출 후 숫자 변환
positions = str2double(stk_data{:, 2:4});
stk_x = positions(:,1);
stk_y = positions(:,2);
stk_z = positions(:,3);


nasa_filename = 'GRACE_FO.csv';
nasa_data = readtable(nasa_filename);
leap_time = 27;
nasa_unix_time = nasa_data{:, 1} + 946728000 - 27;
nasa_x = nasa_data{:,7};
nasa_y = nasa_data{:,8};
nasa_z = nasa_data{:,9};

[common_time, stk_idx, nasa_idx] = intersect(stk_unix_time, nasa_unix_time);

matched_stk_x = stk_x(stk_idx);
matched_stk_y = stk_y(stk_idx);
matched_stk_z = stk_z(stk_idx);

matched_nasa_x = nasa_x(nasa_idx);
matched_nasa_y = nasa_y(nasa_idx);
matched_nasa_z = nasa_z(nasa_idx);

% 오차 계산
error_x = matched_stk_x - matched_nasa_x;
error_y = matched_stk_y - matched_nasa_y;
error_z = matched_stk_z - matched_nasa_z;

% 그래프
figure;
subplot(3,1,1);
plot(common_time, error_x, 'r');
title('X 오차');
xlabel('Unix Time');
ylabel('오차');

subplot(3,1,2);
plot(common_time, error_y, 'g');
title('Y 오차');
xlabel('Unix Time');
ylabel('오차');

subplot(3,1,3);
plot(common_time, error_z, 'b');
title('Z 오차');
xlabel('Unix Time');
ylabel('오차');

sgtitle('Position 오차 그래프');
