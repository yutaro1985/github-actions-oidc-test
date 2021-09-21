terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

locals {
  github_oidc_domain = "vstoken.actions.githubusercontent.com"
  reponame           = "yutaro1985/github-actions-oidc-test"
}

# 呼び出すIAM Roleの定義
resource "aws_iam_role" "github_readonly" {
  name               = "GitHubReadOnlyAccess"
  description        = "ReadOnly from GitHub"
  assume_role_policy = data.aws_iam_policy_document.assume_github.json
}

resource "aws_iam_role_policy_attachment" "readonlyaccess_for_github" {
  role       = aws_iam_role.github_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "sts" {
  name   = "stspolicy"
  role   = aws_iam_role.github_readonly.name
  policy = data.aws_iam_policy_document.sts.json
}

data "aws_iam_policy_document" "sts" {
  statement {
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume_github" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
      "sts:TagSession"
    ]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "${local.github_oidc_domain}:sub"
      values   = ["repo:${local.reponame}"]
    }
  }
}

# Idpの定義
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.github_oidc_domain}"
  client_id_list  = ["sigstore"]
  thumbprint_list = ["a031c46782e6e6c662c2c87c76da9aa62ccabd8e"]
}
