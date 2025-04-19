% CSV 파일 읽기
data = readmatrix('GRACE_FO.csv');

% 결과 저장 배열 초기화
RCI_positions = zeros(size(data, 1), 3);
RCI_velocities = zeros(size(data, 1), 3);

for i = 1:size(data, 1)
    % 위성 위치 및 속도 (ECEF 기준)
    r_ecef = data(i, 7:9)';      % Position: [x; y; z]
    v_ecef = data(i, 10:12)';    % Velocity: [vx; vy; vz]

    % R: Radial (지구 중심 → 위성)
    R_hat = r_ecef / norm(r_ecef);

    % I: In-track (속도 벡터 방향)
    I_hat = v_ecef / norm(v_ecef);

    % C: Cross-track (R과 I의 외적 → 궤도면에 수직)
    C_hat = cross(R_hat, I_hat);
    C_hat = C_hat / norm(C_hat);

    % I 재정의 (직교 보장)
    I_hat = cross(C_hat, R_hat);

    % ECEF to RCI 변환 행렬 (행 벡터 기준)
    T = [R_hat'; C_hat'; I_hat'];

    % RCI 좌표계로 변환
    RCI_positions(i, :) = T * r_ecef;
    RCI_velocities(i, :) = T * v_ecef;
end

% 결과 합치기 및 저장
RCI_data = [RCI_positions RCI_velocities];
writematrix(RCI_data, 'RCI_transformed.csv');
