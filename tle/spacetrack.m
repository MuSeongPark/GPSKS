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
                app.TLETextArea.Value = ['❌ 상호벡터 계산 오류: ', ME.message];
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

            pos = zeros(nTimes, 3);
            vel = zeros(nTimes, 3);

            for i = 1:nTimes
                [r, v] = states(sat, timeVec(i));
                pos(i, :) = r;
                vel(i, :) = v;
            end

            % 시간 형식을 "dd mmm yyyy HH:MM:SS.FFF"로 지정
            timeStr = cellstr(datestr(timeVec', 'dd mmm yyyy HH:MM:SS.FFF'));

            resultTable = table( ...
                timeStr, ...
                pos(:,1), pos(:,2), pos(:,3), ...
                vel(:,1), vel(:,2), vel(:,3), ...
                'VariableNames', {'Time_UTCG', 'x_m', 'y_m', 'z_m', 'vx_mps', 'vy_mps', 'vz_mps'});

            writetable(resultTable, outputCSV);
            app.TLETextArea.Value = ['✔️ "', outputCSV, '"에 저장되었습니다.'];

            previewTable = resultTable(1:min(10, height(resultTable)), :);
            app.UITable.Data = previewTable;
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
                'ColumnName', {'Time', 'x [m]', 'y [m]', 'z [m]', 'vx [m/s]', 'vy [m/s]', 'vz [m/s]'});
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
