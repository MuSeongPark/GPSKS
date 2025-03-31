classdef spacetrack < matlab.apps.AppBase

    % UI 컴포넌트
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        NORADIDEditField   matlab.ui.control.EditField
        StartDatePicker    matlab.ui.control.DatePicker
        EndDatePicker      matlab.ui.control.DatePicker
        SearchButton       matlab.ui.control.Button
        TLETextArea        matlab.ui.control.TextArea
    end

    methods (Access = private)
        
        % TLE 데이터를 가져오는 함수
        function getTLEData(app)
            % 사용자 입력 값 가져오기
            NORADID = app.NORADIDEditField.Value;
            startDate = datestr(app.StartDatePicker.Value, 'yyyy-mm-dd');
            endDate = datestr(app.EndDatePicker.Value, 'yyyy-mm-dd');
            
            % Space-Track 계정 정보
            username = 'oe9981@naver.com';  % Space-Track 계정 사용자 이름
            password = 'Gnu3127221!!!!!';  % Space-Track 계정 비밀번호
            cookiesFile = 'cookies.txt';  % 쿠키 저장 파일
            
            % 로그인 명령어
            loginCommand = sprintf('curl -X POST -d "identity=%s&password=%s" --cookie-jar %s https://www.space-track.org/ajaxauth/login', username, password, cookiesFile);
            
            % 로그인 시도
            [status, loginCmdOut] = system(loginCommand);
            if status ~= 0
                app.TLETextArea.Value = ['Error: Login failed. Details: ', loginCmdOut];
                return;
            end
            
            % TLE 데이터 URL 설정
            url = sprintf('https://www.space-track.org/basicspacedata/query/class/tle/NORAD_CAT_ID/%s/EPOCH/%s--%s/orderby/EPOCH%%20asc/format/tle', NORADID, startDate, endDate);
            
            % curl을 이용해 TLE 데이터 가져오기
            tleCommand = sprintf('curl --cookie %s "%s" -o tle_data.txt', cookiesFile, url);
            [status, tleCmdOut] = system(tleCommand);
            
            if status ~= 0
                app.TLETextArea.Value = ['Error: Unable to fetch TLE data. Details: ', tleCmdOut];
                return;
            end
            
            % TLE 데이터를 파일에서 읽어와서 표시
            try
                fid = fopen('tle_data.txt', 'r');
                if fid == -1
                    app.TLETextArea.Value = 'Error: TLE data file not found or cannot be opened.';
                    return;
                end
                tle_data = fread(fid, '*char')';
                fclose(fid);
                
                % TLE 데이터를 TextArea에 표시
                app.TLETextArea.Value = tle_data;
            catch
                app.TLETextArea.Value = 'Error: Unable to read TLE data from file.';
            end
        end
    end

    % UI 구성 요소 설정
    methods (Access = public)

        % 앱 생성기
        function createComponents(app)
            app.UIFigure = uifigure('Position', [100, 100, 450, 350], 'Name', 'TLE Fetcher');

            % NORAD ID 입력 필드
            uilabel(app.UIFigure, 'Text', 'NORAD ID:', 'Position', [50, 300, 80, 22]);
            app.NORADIDEditField = uieditfield(app.UIFigure, 'text', 'Position', [140, 300, 200, 22]);
            
            % 시작 날짜 선택
            uilabel(app.UIFigure, 'Text', 'Start Date:', 'Position', [50, 260, 80, 22]);
            app.StartDatePicker = uidatepicker(app.UIFigure, 'Position', [140, 260, 200, 22]);
            
            % 종료 날짜 선택
            uilabel(app.UIFigure, 'Text', 'End Date:', 'Position', [50, 220, 80, 22]);
            app.EndDatePicker = uidatepicker(app.UIFigure, 'Position', [140, 220, 200, 22]);
            
            % 검색 버튼
            app.SearchButton = uibutton(app.UIFigure, 'push', 'Text', 'Search', 'Position', [170, 180, 100, 30], ...
                'ButtonPushedFcn', @(btn,event) app.getTLEData());

            % TLE 결과 표시 텍스트 영역
            app.TLETextArea = uitextarea(app.UIFigure, 'Position', [50, 50, 350, 100]);
            app.TLETextArea.Value = 'Enter NORAD ID, select date range, and click Search.';
        end

        % 앱 실행 함수
        function runApp(app)
            createComponents(app);
        end
    end
    
    % 자동으로 GUI 실행
    methods (Access = public)
        function app = spacetrack()
            runApp(app);
        end
    end
end
