classdef spacetrack < matlab.apps.AppBase

    % UI 컴포넌트
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        NORADIDEditField   matlab.ui.control.EditField
        SearchButton       matlab.ui.control.Button
        TLETextArea        matlab.ui.control.TextArea
    end

    methods (Access = private)
        
        % TLE 데이터를 가져오는 함수
        function getTLEData(app, NORADID)
            % 로그인과 쿠키 저장을 위한 curl 호출
            username = 'oe9981@naver.com';  % Space-Track 계정 사용자 이름
            password = 'Ginyu3127221!!!';  % Space-Track 계정 비밀번호
            cookiesFile = 'cookies.txt';  % 쿠키 저장 파일

            % 로그인 명령어
            loginCommand = sprintf('curl -X POST -d "identity=%s&password=%s" --cookie-jar %s https://www.space-track.org/ajaxauth/login', username, password, cookiesFile);
            
            % 로그인 시도
            [status, loginCmdOut] = system(loginCommand);  % system 명령어로 외부 명령 실행

            % 로그인 실패 시, 오류 메시지 출력
            if status ~= 0
                app.TLETextArea.Value = ['Error: Login failed. Details: ', loginCmdOut];
                disp('Login failed!');
                disp(loginCmdOut);  % 로그인 실패 메시지 디버깅
                return;
            end
            disp('Login Successful!');
            disp(loginCmdOut);  % 로그인 성공 메시지 디버깅 출력

            % TLE 데이터 URL 설정 (NORAD ID를 이용한 URL 동적 생성)
            url = sprintf('https://www.space-track.org/basicspacedata/query/class/tle/NORAD_CAT_ID/%s/format/tle', NORADID);

            % curl을 이용해 쿠키를 사용하여 TLE 데이터를 가져오기
            tleCommand = sprintf('curl --cookie %s "%s" -o tle_data.txt', cookiesFile, url);
            [status, tleCmdOut] = system(tleCommand);  % system 명령어로 외부 명령 실행

            % TLE 데이터 요청 결과 확인 (디버깅)
            disp('TLE Request Status:');
            disp(status);
            disp('TLE Request Output:');
            disp(tleCmdOut);

            % TLE 데이터 요청 결과 확인
            if status == 0
                disp('TLE data fetched successfully.');
            else
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
                tle_data = fread(fid, '*char')';  % 파일에서 TLE 데이터 읽기
                fclose(fid);
                
                % TLE 데이터를 TextArea에 표시
                app.TLETextArea.Value = tle_data;  % 읽은 TLE 데이터를 TextArea에 출력
            catch
                % 파일 읽기 오류 발생 시
                app.TLETextArea.Value = 'Error: Unable to read TLE data from file.';
            end
        end
    end

    % UI 구성 요소를 설정하는 코드
    methods (Access = public)

        % 앱 생성기
        function createComponents(app)
            % uifigure 설정
            app.UIFigure = uifigure('Position', [100, 100, 400, 300], 'Name', 'TLE Fetcher');

            % NORAD ID 입력 필드
            app.NORADIDEditField = uieditfield(app.UIFigure, 'text', 'Position', [100, 220, 200, 22]);

            % 검색 버튼
            app.SearchButton = uibutton(app.UIFigure, 'push', 'Text', 'Search', 'Position', [150, 180, 100, 30], ...
                'ButtonPushedFcn', @(btn,event) app.getTLEData(app.NORADIDEditField.Value));

            % TLE 결과 표시 텍스트 영역
            app.TLETextArea = uitextarea(app.UIFigure, 'Position', [50, 50, 300, 100]);
            app.TLETextArea.Value = 'Enter NORAD ID and click Search to get TLE data.';
        end

        % 앱 실행 함수
        function runApp(app)
            createComponents(app);  % 컴포넌트 생성
        end
    end
    
    % 자동으로 GUI 실행
    methods (Access = public)
        function app = spacetrack()
            % 자동으로 GUI를 실행
            runApp(app);
        end
    end
end
