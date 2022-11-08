output "hello_base_url" {
  value = "${aws_apigatewayv2_stage.request.invoke_url}/"
}
