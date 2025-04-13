classdef spacetrack < matlab.apps.AppBase

    % UI 컴포넌트
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        NORADIDEditField   matlab.ui.control.EditField
        StartDatePicker    matlab.ui.control.DatePicker
        EndDatePicker      matlab.ui.control.DatePicker
        SearchButton       matlab.ui.control.Button
        TLETextArea        matlab.ui.control.TextArea
        UITable            matlab.ui.control.Table
    end

    methods (Access = private)

        function getTLEData(app)
            NORADID = app.NORADIDEditField.Value;
            startDate = datestr(app.StartDatePicker.Value, 'yyyy-mm-dd');
            endDate = datestr(app.EndDatePicker.Value, 'yyyy-mm-dd');

            username = 'oe9981@naver.com';
            password = 'Gnu3127221!!!!!';
            cookiesFile = 'cookies.txt';

            loginCmd = sprintf('curl -X POST -d "identity=%s&password=%s" --cookie-jar %s https://www.space-track.org/ajaxauth/login', username, password, cookiesFile);
            [status, loginOut] = system(loginCmd);
            if status ~= 0
                app.TLETextArea.Value = ['❌ 로그인 실패: ', loginOut];
                return;
            end

            tleURL = sprintf('https://www.space-track.org/basicspacedata/query/class/tle/NORAD_CAT_ID/%s/EPOCH/%s--%s/orderby/EPOCH%%20asc/format/tle', ...
                              NORADID, startDate, endDate);
            tleCmd = sprintf('curl --cookie %s "%s" -o tle_data.txt', cookiesFile, tleURL);
            [status, tleOut] = system(tleCmd);
            if status ~= 0
                app.TLETextArea.Value = ['❌ TLE 다운로드 실패: ', tleOut];
                return;
            end

            try
                fid = fopen('tle_data.txt', 'r');
                tle_data = fread(fid, '*char')';
                fclose(fid);
                app.TLETextArea.Value = tle_data;
            catch
                app.TLETextArea.Value = '❌ TLE 파일 읽기 실패';
                return;
            end

            try
                app.computeStateVectors(NORADID, app.StartDatePicker.Value);
            catch ME
                app.TLETextArea.Value = ['❌ 상태벡터 계산 오류: ', ME.message];
            end
        end

        function computeStateVectors(app, NORADID, startDateTime)
            satelliteName = NORADID;
            startTime = startDateTime;
            duration = days(1);
            sampleInterval = 1;
            outputCSV = 'satellite_state_vectors.csv';

            stopTime = startTime + duration;
            sc = satelliteScenario(startTime, stopTime, sampleInterval);
            sat = satellite(sc, 'tle_data.txt', 'Name', satelliteName, 'OrbitPropagator', 'sgp4');

            timeVec = startTime:seconds(sampleInterval):stopTime;
            nTimes = numel(timeVec);

            pos_ecef = zeros(nTimes, 3);   % ECEF
            vel_ecef = zeros(nTimes, 3);   % ECEF

            for i = 1:nTimes
                [r, v] = states(sat, timeVec(i));  % TEME 좌표
                jd = juliandate(timeVec(i));
                [r_ecef, v_ecef] = app.teme2ecef(r, v, jd);  % TEME → ECEF 변환
                pos_ecef(i, :) = r_ecef;
                vel_ecef(i, :) = v_ecef;
            end

            timeStr = cellstr(datestr(timeVec', 'dd mmm yyyy HH:MM:SS.FFF'));

            resultTable = table( ...
                timeStr, ...
                pos_ecef(:,1), pos_ecef(:,2), pos_ecef(:,3), ...
                vel_ecef(:,1), vel_ecef(:,2), vel_ecef(:,3), ...
                'VariableNames', {'Time_UTCG', ...
                                  'ECEF_x_m', 'ECEF_y_m', 'ECEF_z_m', ...
                                  'ECEF_vx_mps', 'ECEF_vy_mps', 'ECEF_vz_mps'});

            writetable(resultTable, outputCSV);
            app.TLETextArea.Value = ['✔️ "', outputCSV, '"에 저장되었습니다.'];

            previewTable = resultTable(1:min(10, height(resultTable)), :);
            app.UITable.Data = previewTable;
        end

        function [r_ecef, v_ecef] = teme2ecef(app, r_teme, v_teme, jd)
            gmst = app.siderealTime(jd);  % rad
        
            R = [cos(gmst), sin(gmst), 0;
                 -sin(gmst), cos(gmst), 0;
                 0, 0, 1];
        
            r_ecef = (R * r_teme(:))';  % r_teme(:)는 3x1 열벡터 → 결과는 1x3
            v_ecef = (R * v_teme(:))';
        end

        function theta = siderealTime(~, jd)
            T = (jd - 2451545.0) / 36525.0;
            theta_sec = 67310.54841 + (876600*3600 + 8640184.812866)*T + 0.093104*T^2 - 6.2e-6*T^3;
            theta_sec = mod(theta_sec, 86400);
            theta = theta_sec * (pi / 43200);  % radian
        end
    end

    methods (Access = public)

        function createComponents(app)
            app.UIFigure = uifigure('Position', [100, 100, 800, 600], 'Name', 'TLE Fetcher');

            uilabel(app.UIFigure, 'Text', 'NORAD ID:', 'Position', [50, 540, 100, 25]);
            app.NORADIDEditField = uieditfield(app.UIFigure, 'text', 'Position', [160, 540, 300, 25]);

            uilabel(app.UIFigure, 'Text', 'Start Date:', 'Position', [50, 500, 100, 25]);
            app.StartDatePicker = uidatepicker(app.UIFigure, 'Position', [160, 500, 300, 25]);

            uilabel(app.UIFigure, 'Text', 'End Date:', 'Position', [50, 460, 100, 25]);
            app.EndDatePicker = uidatepicker(app.UIFigure, 'Position', [160, 460, 300, 25]);

            app.SearchButton = uibutton(app.UIFigure, 'push', 'Text', 'Search', ...
                'Position', [500, 500, 100, 30], ...
                'ButtonPushedFcn', @(btn, event) app.getTLEData());

            app.TLETextArea = uitextarea(app.UIFigure, 'Position', [50, 20, 700, 120]);
            app.TLETextArea.Value = 'Enter NORAD ID and date range, then click Search.';

            app.UITable = uitable(app.UIFigure, ...
                'Position', [50, 160, 700, 280], ...
                'ColumnName', {'Time', 'ECEF x [m]', 'ECEF y [m]', 'ECEF z [m]', ...
                               'ECEF vx [m/s]', 'ECEF vy [m/s]', 'ECEF vz [m/s]'});
        end

        function runApp(app)
            createComponents(app);
        end
    end

    methods (Access = public)
        function app = spacetrack()
            runApp(app);
        end
    end
end
