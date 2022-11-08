########################Dynamodb########################

resource "aws_dynamodb_table" "this" {
  name         = "hello-world-table"
  hash_key     = "message"
  read_capacity = 1
  write_capacity = 1

  attribute {
    name = "message"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "this" {
  table_name = aws_dynamodb_table.this.name
  hash_key   = aws_dynamodb_table.this.hash_key

  item = <<ITEM
{
  "message": {"S": "Hello World"},
  "env": {"S": "${var.env}"}
}
ITEM
}

########################IAM########################

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


data "aws_iam_policy_document" "dynamo" {
  statement {
    sid       = "AllowDynamoPermissions"
    effect    = "Allow"
    resources = ["*"]

    actions = ["dynamodb:*"]
  }

  statement {
    sid       = "AllowInvokingLambdas"
    effect    = "Allow"
    resources = ["arn:aws:lambda:*:*:function:*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = "AllowCreatingLogGroups"
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
    actions   = ["logs:CreateLogGroup"]
  }

  statement {
    sid       = "AllowWritingLogs"
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/*:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_role" "dynamo" {
  name               = "dynamo-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
}

resource "aws_iam_policy" "dynamo" {
  name   = "dynamo-lambda-execute-policy"
  policy = data.aws_iam_policy_document.dynamo.json
}

resource "aws_iam_role_policy_attachment" "dynamo" {
  policy_arn = aws_iam_policy.dynamo.arn
  role       = aws_iam_role.dynamo.name
}

########################Lambda########################

data "archive_file" "dynamo" {
    type          = "zip"
    source_file   = "../lambda/index.js"
    output_path   = "dynamo-artefact.zip"
}

resource "aws_lambda_function" "dynamo" {
  function_name = "dynamo"
  handler       = "index.handler"
  role          = aws_iam_role.dynamo.arn
  runtime       = "nodejs16.x"

  filename         = data.archive_file.dynamo.output_path
  source_code_hash = data.archive_file.dynamo.output_base64sha256

  timeout     = 30
  memory_size = 128
}

########################API Gateway########################

resource "aws_apigatewayv2_api" "api-gw-hello" {
  name          = "api-gw-hello"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "request" {
  name        = "request"
  api_id      = aws_apigatewayv2_api.api-gw-hello.id
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_hello" {
  api_id = aws_apigatewayv2_api.api-gw-hello.id

  integration_uri    =  aws_lambda_function.dynamo.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_hello" {
  api_id = aws_apigatewayv2_api.api-gw-hello.id

  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_hello.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dynamo.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api-gw-hello.execution_arn}/*/*"
}