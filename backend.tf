# backend.tf

terraform {
  backend "s3" {
    # ↓↓↓ ステップ1で作ったS3バケットの名前に書き換える
    bucket = "tfstate-your-unique-name-20240730"
    
    # S3バケットの中に、この名前でtfstateファイルが作られる
    key    = "terraform.tfstate"
    
    # S3バケットが存在するリージョン
    region = "ap-northeast-1"
  }
}