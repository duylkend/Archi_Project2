terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  # version of terraform
  required_version = ">= 1.2.0"
}

provider "aws" {
  accessxxx_key = "xxxxxxxxxxxxxxxxxx"
  secretxxx_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  region = var.aws_region
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "greet_lambda.py"
  output_path = "greet_lambda.zip"
}

resource "aws_lambda_function" "greet_lambda" {
  filename      = "greet_lambda.zip"
  function_name = var.lambda_func_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "greet_lambda.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime = "python3.8"
  depends_on = [
    aws_iam_role.iam_for_lambda,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.cloud_watch_log_for_lambda,
  ]

  environment {
    variables = {
      greeting = "greeting HKT"
    }
  }
}

resource "aws_cloudwatch_log_group" "cloud_watch_log_for_lambda" {
  name              = "/aws/lambda/${var.lambda_func_name}"
  retention_in_days = 7
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}