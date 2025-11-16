plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  call_module_type = "all"
  force = false
}

# 네이밍 컨벤션 검사
rule "terraform_naming_convention" {
  enabled = true
}

# 더 이상 사용되지 않는 interpolation 구문 검사
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# 변수에 대한 설명(description) 필수
rule "terraform_documented_variables" {
  enabled = true
}

# output에 대한 설명 필수
rule "terraform_documented_outputs" {
  enabled = true
}

# 사용되지 않는 선언 검사
rule "terraform_unused_declarations" {
  enabled = true
}

# 표준 모듈 구조 검사
rule "terraform_standard_module_structure" {
  enabled = true
}

# typed variables 검사
rule "terraform_typed_variables" {
  enabled = true
}
