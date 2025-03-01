## 로컬에서 Terraform 실행 방법

---

1. **기본 세팅**
    
    curl -o /etc/yum.repos.d/terraform.repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    
    yum install -y terraform
    
    terraform --version
    
2. **.tf 파일 작성**
    
    테라폼을 수행할 디렉토리 내의 .tf 형식으로 작성된 모든 파일이 수행됨 
    
3. **Terraform 초기화**
    - terraform init
        - Terraform 프로젝트에서 실행하는 첫 번째 명령어, 수행할 작업 디렉토리를 Terraform 작업 공간으로 초기화하는 역할
4. **apply 전 변경 사항 확인**
    - terraform plan
        - .tf 파일 기반으로 현재 aws 인프라 상태와 비교하여 변경사항 미리 확인
5. **terraform 실행**
    - terraform apply
6. **생성된 리소스 AWS 콘솔에서 확인**

+ 콘솔에서 사용되던 리소스를 중간에 . tf 파일에 작성하여 자동화시키고싶다면, terraform import 명령어로 fstate 파일에 리소스 동기화 후에 plan 으로 변경사항 확인 후 해당 내용 기반으로 .tf 파일 작성수행. apply 전 다시 plan으로 리소스와 일치여부를 '변경사항 없음'으로 확인 후 apply 를 수행하면 자동화 가능
