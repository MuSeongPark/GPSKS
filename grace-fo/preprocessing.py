import os
import tarfile
import re

# .tgz 파일들이 있는 디렉토리
input_dir = "C:/GPSKS/grace-fo/zip"     # TODO: 여기에 tgz 파일들이 있는 경로를 지정하세요
output_dir = "C:/GPSKS/grace-fo/dataset"  # TODO: CSV를 저장할 디렉토리

# 출력 폴더가 없다면 생성
os.makedirs(output_dir, exist_ok=True)

# .tgz 파일 목록 가져오기
tgz_files = [f for f in os.listdir(input_dir) if f.endswith('.tgz')]

for tgz_file in tgz_files:
    tgz_path = os.path.join(input_dir, tgz_file)

    with tarfile.open(tgz_path, "r:gz") as tar:
        # GNV1A_YYYY_MM_DD.txt 파일 찾기
        for member in tar.getmembers():
            if re.search(r"GNV1A_\d{4}-\d{2}-\d{2}_D_04.txt$", member.name):
                file = tar.extractfile(member)
                if file:
                    lines = file.read().decode('utf-8').splitlines()
                    
                    # "# End of YAML header" 까지의 줄 제거
                    for i, line in enumerate(lines):
                        if line.strip() == "# End of YAML header":
                            data_lines = lines[i+1:]  # 헤더 이후 데이터 줄만 저장
                            break
                    else:
                        print(f"YAML 헤더 종료 태그를 찾지 못했습니다: {member.name}")
                        data_lines = []  # 해당 태그가 없을 경우 빈 리스트로 처리

                    # 날짜 추출
                    date_match = re.search(r"GNV1A_(\d{4})-(\d{2})-(\d{2})_D_04.txt", member.name)
                    if date_match:
                        print("hello")
                        y, m, d = date_match.groups()
                        csv_name = f"GNV1A_{y}_{m}_{d}.csv"
                        output_path = os.path.join(output_dir, csv_name)

                        # CSV 파일로 저장
                        with open(output_path, 'w', encoding='utf-8') as out_csv:
                            for line in data_lines:
                                out_csv.write(line + '\n')

                        print(f"저장 완료: {csv_name} ({len(data_lines)}줄)")
