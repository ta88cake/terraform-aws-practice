# main.tf

# --- プロバイダーの定義 ---
# どのクラウドを使うか (AWS)
provider "aws" {
  region = "ap-northeast-1" # 東京リージョン
}
# --- VPCリソースの定義 ---
# これがVPC本体の設計図
resource "aws_vpc" "my_first_vpc" {
  # VPCに割り当てるIPアドレスの範囲を指定します。
  # "10.0.0.0/16" は、約65,000個のIPアドレスが使える、とても一般的な設定です。
  cidr_block = "10.0.0.0/16"

  # VPCに名前をつけるためのタグ
  tags = {
    Name = "my-first-vpc-from-terraform"
  }
}
# main.tf (追記)

resource "aws_key_pair" "my_key" {
  key_name   = "my-first-key"
  public_key = file("my-key.pub")
}
# --- サブネットリソースの定義 ---
resource "aws_subnet" "my_public_subnet" {
  # このサブネットが、どのVPCに属するかを指定します。
  # ここで、先ほど作ったVPCリソースのIDを参照しています。
  vpc_id = aws_vpc.my_first_vpc.id

  # サブネットに割り当てるIPアドレスの範囲を指定します。
  # VPCの範囲("10.0.0.0/16")の、一部分("10.0.1.0/24")を使います。
  cidr_block = "10.0.1.0/24"

  # どのAvailability Zoneに作成するか指定します。
  # "ap-northeast-1a" は東京リージョンにあるデータセンターの一つです。
  availability_zone = "ap-northeast-1a"

  map_public_ip_on_launch = true

  # サブネットに名前をつけるためのタグ
  tags = {
    Name = "my-public-subnet"
  }
}
# main.tf (追記)

# --- インターネットゲートウェイの定義 ---
resource "aws_internet_gateway" "my_igw" {
  # どのVPCに取り付けるかを指定
  vpc_id = aws_vpc.my_first_vpc.id

  tags = {
    Name = "my-igw"
  }
}

# --- ルートテーブルの定義 ---
resource "aws_route_table" "my_public_rt" {
  # どのVPCに属するルートテーブルかを指定
  vpc_id = aws_vpc.my_first_vpc.id

  # 「ルート（経路）」のルールを定義
  route {
    # 宛先が "0.0.0.0/0" (つまり、インターネット上のどこか) の通信は...
    cidr_block = "0.0.0.0/0"
    # ...このゲートウェイを通りなさい、というルール
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my-public-route-table"
  }
}
# main.tf (さらに追記)

# --- ルートテーブルとサブネットの関連付け ---
resource "aws_route_table_association" "public_subnet_assoc" {
  # どのサブネットに...
  subnet_id = aws_subnet.my_public_subnet.id
  # ...どのルートテーブルを適用するか
  route_table_id = aws_route_table.my_public_rt.id
}
# main.tf (追記)

# --- セキュリティグループの定義 ---
resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Allow HTTP traffic for web server"
  # どのVPCに属するセキュリティグループかを指定
  vpc_id = aws_vpc.my_first_vpc.id

  # 「イングレス（内向き）」のルール
  # どんな通信の進入を許可するか
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # "0.0.0.0/0" は「どこからでも」を意味する特別なCIDRブロック
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 「エグレス（外向き）」のルール
  # どこへの通信を許可するか
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1" # "-1" は「すべてのプロトコル」を意味する
    # 基本的に、出ていく通信はすべて許可するのが一般的
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}
# main.tf (追記)

# --- EC2インスタンスの定義 ---
resource "aws_instance" "my_web_server" {
  # どのOSイメージを使うか？
  # ここで、以前データソースで取得した最新のAmazon Linux 2のAMI IDを使います！
  ami = data.aws_ami.latest_amazon_linux.id

  # どの性能のサーバーにするか？ (一番小さい無料利用枠のタイプ)
  instance_type = "t2.micro"
  
  # どのサブネットに配置するか？
  # 我々が作ったパブリックサブネットを指定します。
  subnet_id = aws_subnet.my_public_subnet.id
  # どのセキュリティグループを適用するか？
  # 我々が作ったWebサーバー用のセキュリティグループを指定します。
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  key_name = aws_key_pair.my_key.key_name
  # 起動時に簡単なWebサーバーをインストールするスクリプト
  # これにより、起動後すぐにWebページが表示されるようになります。
  # user_data を、Dockerをインストールし、Docker Hubからイメージをpullして実行するスクリプトに書き換える
  user_data = <<-EOF
            #!/bin/bash
            # Dockerのインストール
            yum update -y
            yum install -y docker
            systemctl start docker
            systemctl enable docker
            usermod -aG docker ec2-user

            # Docker Hubから、CIパイプラインがビルドしたイメージをpullして実行
            # docker run -d -p 80:80 [あなたのDocker Hubユーザー名]/terraform-aws-practice:latest
            # ↓↓↓ 【重要】下の行の "ta88cake" の部分を、あなたのDocker Hubユーザー名に書き換えてください！
            docker run -d -p 80:80 --name rag-app ta88cake/terraform-aws-practice:latest
            EOF

  # EC2インスタンスに名前をつけるためのタグ
  tags = {
    Name = "My-Web-Server"
  }
}