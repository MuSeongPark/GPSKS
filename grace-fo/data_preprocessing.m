% 데이터 파일 경로
filename = 'GRACE-FO_2_43477_j2000.csv';

% 파일 옵션 설정: 모든 열을 문자열로 먼저 불러오기
opts = detectImportOptions(filename);
opts = setvartype(opts, 'char');
data = readtable(filename, opts);

% UTC 기준 시간 문자열을 datetime으로 변환
datetime_format = 'dd MMM yyyy HH:mm:ss.SSS'; 
time_strings = data{:,1};
t_utc = datetime(time_strings, 'InputFormat', datetime_format, ...
                 'Locale', 'en_US', 'TimeZone', 'UTC');

% Unix Time 변환
unix_time = posixtime(t_utc);



% Position 데이터 (x, y, z) 추출 후 숫자 변환
positions = str2double(data{:, 2:4});
x = positions(:,1);
y = positions(:,2);
z = positions(:,3);

% 오차 계산 (평균 기준)
x_err = x - mean(x);
y_err = y - mean(y);
z_err = z - mean(z);

% 그래프 그리기
figure;
subplot(3,1,1);
plot(unix_time, x_err, 'r');
title('X 오차');
xlabel('Unix Time (UTC)');
ylabel('오차');

subplot(3,1,2);
plot(unix_time, y_err, 'g');
title('Y 오차');
xlabel('Unix Time (UTC)');
ylabel('오차');

subplot(3,1,3);
plot(unix_time, z_err, 'b');
title('Z 오차');
xlabel('Unix Time (UTC)');
ylabel('오차');

sgtitle('Position 오차 그래프 (UTC 기준, 평균 기준 오차)');
